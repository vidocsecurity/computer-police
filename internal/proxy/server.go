package proxy

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"computer-police/internal/paths"
)

const (
	DefaultHost         = "127.0.0.1"
	DefaultPort         = 4873
	DefaultUpstream     = "https://registry.npmjs.org/"
	DefaultPyPIUpstream = "https://pypi.org/"
)

type ServerOptions struct {
	Host         string
	Port         int
	Upstream     string
	PyPIUpstream string
}

func (o ServerOptions) withDefaults() ServerOptions {
	if o.Host == "" {
		o.Host = DefaultHost
	}
	if o.Port == 0 {
		o.Port = DefaultPort
	}
	if o.Upstream == "" {
		o.Upstream = DefaultUpstream
	}
	if o.PyPIUpstream == "" {
		o.PyPIUpstream = DefaultPyPIUpstream
	}
	return o
}

type Inspector interface {
	Inspect(*http.Request, RequestInfo) Decision
}

type ResponseInspector interface {
	InspectResponse(*http.Request, RequestInfo, *http.Response, []byte) Decision
}

type ResponseRewriter interface {
	RewriteResponse(*http.Request, RequestInfo, *http.Response, []byte) ResponseRewrite
}

type Decision struct {
	Allowed   bool
	Reason    string
	BlockedBy string
}

type ResponseRewrite struct {
	Decision
	Body []byte
}

type AllowAllInspector struct{}

func (AllowAllInspector) Inspect(*http.Request, RequestInfo) Decision {
	return Decision{Allowed: true}
}

type RegistryProxy struct {
	upstream     *url.URL
	pypiUpstream *url.URL
	client       *http.Client
	inspector    Inspector
}

func NewRegistryProxy(upstream string, inspector Inspector) (*RegistryProxy, error) {
	return NewRegistryProxyWithUpstreams(upstream, upstream, inspector)
}

func NewRegistryProxyWithUpstreams(upstream, pypiUpstream string, inspector Inspector) (*RegistryProxy, error) {
	parsed, err := url.Parse(upstream)
	if err != nil {
		return nil, err
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("invalid upstream registry %q", upstream)
	}
	parsedPyPI, err := url.Parse(pypiUpstream)
	if err != nil {
		return nil, err
	}
	if parsedPyPI.Scheme == "" || parsedPyPI.Host == "" {
		return nil, fmt.Errorf("invalid PyPI upstream registry %q", pypiUpstream)
	}
	if inspector == nil {
		inspector = AllowAllInspector{}
	}
	return &RegistryProxy{
		upstream:     parsed,
		pypiUpstream: parsedPyPI,
		client: &http.Client{
			Timeout: 10 * time.Minute,
			Transport: &http.Transport{
				Proxy:               http.ProxyFromEnvironment,
				MaxIdleConns:        100,
				MaxIdleConnsPerHost: 20,
				IdleConnTimeout:     90 * time.Second,
			},
		},
		inspector: inspector,
	}, nil
}

func (p *RegistryProxy) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	info := classifyRequest(r.URL.Path)
	upstream := p.upstreamFor(info)
	status := http.StatusBadGateway
	var blockReason string
	var blockedBy string
	defer func() {
		event := Event{
			SchemaVersion: "1.0",
			EventType:     "registry_request_observed",
			EventID:       eventID(),
			Timestamp:     time.Now().UTC().Format(time.RFC3339Nano),
			Source:        "local_registry_proxy",
			Request: EventRequest{
				Method:      r.Method,
				Path:        requestPath(r),
				Type:        info.Type,
				Ecosystem:   info.Ecosystem,
				Package:     info.Package,
				Version:     info.Version,
				StatusCode:  status,
				DurationMS:  time.Since(start).Milliseconds(),
				BlockedBy:   blockedBy,
				BlockReason: blockReason,
			},
			Upstream: EventUpstream{Registry: upstream.String()},
			Client: EventClient{
				UserAgent:           r.UserAgent(),
				PackageManagerGuess: guessPackageManager(r.UserAgent()),
				RemoteAddr:          hostPort(r.RemoteAddr),
			},
			Privacy: EventPrivacy{AuthHeadersLogged: false, BodyLogged: false},
		}
		_ = appendEvent(event)
	}()

	decision := p.inspector.Inspect(r, info)
	if !decision.Allowed {
		status = http.StatusForbidden
		blockReason = decision.Reason
		blockedBy = decision.BlockedBy
		http.Error(w, "blocked by Computer Police registry policy", status)
		return
	}

	upstreamURL := strings.TrimRight(upstream.String(), "/") + r.URL.RequestURI()
	req, err := http.NewRequestWithContext(r.Context(), r.Method, upstreamURL, r.Body)
	if err != nil {
		status = http.StatusInternalServerError
		http.Error(w, err.Error(), status)
		return
	}
	copyHeaders(req.Header, r.Header)
	applyUpstreamAuth(req, upstream)
	req.Host = upstream.Host

	resp, err := p.client.Do(req)
	if err != nil {
		status = http.StatusBadGateway
		http.Error(w, err.Error(), status)
		return
	}
	defer resp.Body.Close()

	if responseInspector, ok := p.inspector.(ResponseInspector); ok && shouldInspectResponse(info, resp) {
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			status = http.StatusBadGateway
			http.Error(w, err.Error(), status)
			return
		}
		decision := responseInspector.InspectResponse(r, info, resp, body)
		if !decision.Allowed {
			status = http.StatusForbidden
			blockReason = decision.Reason
			blockedBy = decision.BlockedBy
			http.Error(w, "blocked by Computer Police registry policy", status)
			return
		}
		if rewriter, ok := p.inspector.(ResponseRewriter); ok {
			rewrite := rewriter.RewriteResponse(r, info, resp, body)
			if !rewrite.Allowed {
				status = http.StatusForbidden
				blockReason = rewrite.Reason
				blockedBy = rewrite.BlockedBy
				http.Error(w, "blocked by Computer Police registry policy", status)
				return
			}
			if rewrite.Body != nil {
				body = rewrite.Body
			}
		}
		status = resp.StatusCode
		copyHeaders(w.Header(), resp.Header)
		w.Header().Del("Content-Length")
		w.WriteHeader(resp.StatusCode)
		_, _ = w.Write(body)
		return
	}

	status = resp.StatusCode
	copyHeaders(w.Header(), resp.Header)
	w.WriteHeader(resp.StatusCode)
	_, _ = io.Copy(w, resp.Body)
}

func shouldInspectResponse(info RequestInfo, resp *http.Response) bool {
	if resp.StatusCode >= 400 {
		return false
	}
	contentType := strings.ToLower(resp.Header.Get("Content-Type"))
	switch info.Type {
	case "metadata":
		return strings.Contains(contentType, "json") || contentType == ""
	case "pypi_metadata":
		return strings.Contains(contentType, "html") || strings.Contains(contentType, "text") || contentType == ""
	default:
		return false
	}
}

func (p *RegistryProxy) upstreamFor(info RequestInfo) *url.URL {
	if info.Ecosystem == "PyPI" && p.pypiUpstream != nil {
		return p.pypiUpstream
	}
	return p.upstream
}

func RunForeground(out io.Writer, opts ServerOptions) error {
	opts = opts.withDefaults()
	if opts.Host == "0.0.0.0" || opts.Host == "::" {
		fmt.Fprintf(out, "warning: binding Computer Police registry proxy to %s exposes it beyond loopback\n", opts.Host)
	}
	advisoryStore := NewMalwareAdvisoryStoreFromEnv()
	advisoryStore.StartBackgroundRefresh(context.Background())
	handler, err := NewRegistryProxyWithUpstreams(opts.Upstream, opts.PyPIUpstream, &MalwareInspector{store: advisoryStore})
	if err != nil {
		return err
	}
	addr := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	if err := writePID(os.Getpid(), listener.Addr().String(), opts.Upstream); err != nil {
		_ = listener.Close()
		return err
	}
	defer os.Remove(paths.RegistryProxyPIDPath())
	fmt.Fprintf(out, "Computer Police registry proxy listening on http://%s\n", listener.Addr().String())
	mux := http.NewServeMux()
	mountAPIHandlers(mux, advisoryStore)
	mux.Handle("/", handler)
	server := &http.Server{Handler: mux}
	return server.Serve(listener)
}

func requestPath(r *http.Request) string {
	if r.URL.RawQuery == "" {
		return r.URL.EscapedPath()
	}
	values := r.URL.Query()
	for key := range values {
		if secretQueryParam(key) {
			values.Set(key, "REDACTED")
		}
	}
	return r.URL.EscapedPath() + "?" + values.Encode()
}

func copyHeaders(dst, src http.Header) {
	for key, values := range src {
		if isHopHeader(key) || isConditionalRequestHeader(key) || isProxyControlledRequestHeader(key) {
			continue
		}
		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

func isProxyControlledRequestHeader(key string) bool {
	switch strings.ToLower(key) {
	case "accept-encoding":
		return true
	default:
		return false
	}
}

func isConditionalRequestHeader(key string) bool {
	switch strings.ToLower(key) {
	case "if-match", "if-modified-since", "if-none-match", "if-range", "if-unmodified-since":
		return true
	default:
		return false
	}
}

func isHopHeader(key string) bool {
	switch strings.ToLower(key) {
	case "connection", "proxy-connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade":
		return true
	default:
		return false
	}
}

func secretQueryParam(key string) bool {
	normalized := strings.ToLower(key)
	return strings.Contains(normalized, "token") ||
		strings.Contains(normalized, "auth") ||
		strings.Contains(normalized, "password") ||
		strings.Contains(normalized, "secret")
}

func reachable(ctx context.Context, registry string) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(registry, "/")+"/-/ping", nil)
	if err != nil {
		return false
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode < 500
}

func writePID(pid int, addr, upstream string) error {
	if err := os.MkdirAll(filepath.Dir(paths.RegistryProxyPIDPath()), 0o755); err != nil {
		return err
	}
	data := fmt.Sprintf("%d\n%s\n%s\n", pid, addr, upstream)
	return os.WriteFile(paths.RegistryProxyPIDPath(), []byte(data), 0o644)
}
