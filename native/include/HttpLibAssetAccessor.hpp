#include <Cesium3DTilesSelection/Tileset.h>
#include <Cesium3DTilesSelection/TilesetExternals.h>
#include <CesiumAsync/IAssetAccessor.h>
#include <CesiumAsync/IAssetResponse.h>
#include <CesiumAsync/AsyncSystem.h>
#define CPPHTTPLIB_OPENSSL_SUPPORT

#include <httplib.h>
#include <memory>
#include <vector>
#include <string>
#include <stdexcept>

using namespace Cesium3DTilesSelection;

class HttplibAssetResponse : public CesiumAsync::IAssetResponse {
public:
    HttplibAssetResponse(int statusCode, const httplib::Headers& headers, const std::string& body)
        : _statusCode(statusCode), _body(body) {
        for (const auto& header : headers) {
            _headers.emplace(header.first, header.second);
        }
    }

    virtual uint16_t statusCode() const override { return static_cast<uint16_t>(_statusCode); }
    virtual const CesiumAsync::HttpHeaders& headers() const override { return _headers; }
    virtual gsl::span<const std::byte> data() const override {
        return gsl::span<const std::byte>(reinterpret_cast<const std::byte*>(_body.data()), _body.size());
    }
    virtual std::string contentType() const override {
        auto it = _headers.find("Content-Type");
        return it != _headers.end() ? it->second : "";
    }

private:
    int _statusCode;
    CesiumAsync::HttpHeaders _headers;
    std::string _body;
};

class HttplibAssetRequest : public CesiumAsync::IAssetRequest {
public:
    HttplibAssetRequest(const std::string& method, const std::string& url, const CesiumAsync::HttpHeaders& headers)
        : _method(method), _url(url), _headers(headers) {}

    virtual const std::string& method() const override { return _method; }
    virtual const std::string& url() const override { return _url; }
    virtual const CesiumAsync::HttpHeaders& headers() const override { return _headers; }
    virtual const CesiumAsync::IAssetResponse* response() const override { return _response.get(); }

    void setResponse(std::unique_ptr<HttplibAssetResponse> response) {
        _response = std::move(response);
    }

private:
    std::string _method;
    std::string _url;
    CesiumAsync::HttpHeaders _headers;
    std::unique_ptr<HttplibAssetResponse> _response;
};

class HttplibAssetAccessor : public CesiumAsync::IAssetAccessor {
public:
    HttplibAssetAccessor(const std::string& authToken = "") : _authToken(authToken) {}

    void setAuthToken(const std::string& authToken) {
        _authToken = authToken;
    }

    CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> get(
        const CesiumAsync::AsyncSystem& asyncSystem,
        const std::string& url,
        const std::vector<CesiumAsync::IAssetAccessor::THeader>& headers) override {
        return request(asyncSystem, "GET", url, headers);
    }

    CesiumAsync::Future<std::shared_ptr<CesiumAsync::IAssetRequest>> request(
        const CesiumAsync::AsyncSystem& asyncSystem,
        const std::string& verb,
        const std::string& url,
        const std::vector<THeader>& headers,
        const gsl::span<const std::byte>& contentPayload = {}) override {
       
        return asyncSystem.runInWorkerThread([this, verb, url, headers, contentPayload]() {
            auto request = std::make_shared<HttplibAssetRequest>(verb, url, CesiumAsync::HttpHeaders(headers.begin(), headers.end()));
            
       // Parse the URL
            std::regex url_regex("(https?)://([^/:]+)(?::(\\d+))?(/.*)?");
            std::smatch url_match;
            if (!std::regex_match(url, url_match, url_regex)) {
                throw std::runtime_error("Invalid URL format: " + url);
            }
            
            std::string scheme = url_match[1].str();
            std::string host = url_match[2].str();
            std::string port = url_match[3].str();
            std::string path = url_match[4].matched ? url_match[4].str() : "/";

            // Create the client with scheme, host, and port
            std::unique_ptr<httplib::Client> cli;
            if (scheme == "https") {
                cli = std::make_unique<httplib::SSLClient>(host, port.empty() ? 443 : std::stoi(port));
            } else if (scheme == "http") {
                cli = std::make_unique<httplib::Client>(host, port.empty() ? 80 : std::stoi(port));
            } else {
                throw std::runtime_error("Unsupported scheme: " + scheme);
            }
            cli.set_connection_timeout(300);
            cli.set_read_timeout(300);
            cli.set_write_timeout(300);

       
            httplib::Headers httplib_headers;
            for (const auto& header : headers) {
                httplib_headers.emplace(header.first, header.second);
            }

            httplib_headers.emplace("Accept-Encoding", "gzip, deflate");

            if (!_authToken.empty()) {
                httplib_headers.emplace("Authorization", "Bearer " + _authToken);
            }

            std::cout << "Request headers:" << std::endl;
            for (const auto& header : httplib_headers) {
                std::cout << header.first << ": " << header.second << std::endl;
            }
            std::cout << "requesting " << url << std::endl;

            httplib::Result res;
            if (verb == "GET") {
                res = cli.Get(path.c_str(), httplib_headers);
            } else if (verb == "POST") {
                res = cli.Post(path.c_str(), httplib_headers, 
                               reinterpret_cast<const char*>(contentPayload.data()), 
                               contentPayload.size(), 
                               "application/octet-stream");
            } else {
                throw std::runtime_error("Unsupported HTTP method: " + verb);
            }

            if (res.error() != httplib::Error::Success) {
                std::stringstream errorMsg;
                errorMsg << "HTTP request failed: " << httplib::to_string(res.error());
                errorMsg << " (Error code: " << static_cast<int>(res.error()) << ")";
                
                if (res) {
                    errorMsg << "\nStatus code: " << res->status;
                    errorMsg << "\nResponse body: " << res->body;
                }
                
                
                    std::cout << errorMsg.str() << std::endl;
                
                throw std::runtime_error(errorMsg.str());
            }

            auto response = std::make_unique<HttplibAssetResponse>(res->status, res->headers, res->body);
            request->setResponse(std::move(response));

            return std::static_pointer_cast<CesiumAsync::IAssetRequest>(request);
        });
    }

    void tick() noexcept override {}

private:
    std::string _authToken;
};