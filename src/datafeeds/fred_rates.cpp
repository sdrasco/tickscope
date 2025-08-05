#include "fred_rates.h"

#include <curl/curl.h>
#include <string>

namespace {
size_t WriteCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    std::string *s = static_cast<std::string *>(userp);
    s->append(static_cast<char *>(contents), size * nmemb);
    return size * nmemb;
}
}

FredRateLoader::FredRateLoader(std::string apiKey) : apiKey_(std::move(apiKey)) {}

bool FredRateLoader::isStale() const {
    if (!data_.valid) return true;
    auto now = std::chrono::system_clock::now();
    return (now - data_.fetched) > std::chrono::hours(24);
}

std::optional<double> FredRateLoader::fetchRate(const std::string &seriesId) {
    CURL *curl = curl_easy_init();
    if (!curl) return std::nullopt;

    std::string url = "https://api.stlouisfed.org/fred/series/observations?series_id=" + seriesId +
                      "&api_key=" + apiKey_ + "&file_type=json&sort_order=desc&limit=1";
    std::string buffer;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buffer);

    CURLcode res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);
    if (res != CURLE_OK) return std::nullopt;

    auto pos = buffer.find("\"value\":");
    if (pos == std::string::npos) return std::nullopt;
    pos = buffer.find('"', pos + 7); // move to first quote after value:
    if (pos == std::string::npos) return std::nullopt;
    ++pos;
    size_t end = buffer.find('"', pos);
    if (end == std::string::npos) return std::nullopt;

    std::string valStr = buffer.substr(pos, end - pos);
    if (valStr == "." || valStr.empty()) return std::nullopt;

    try {
        double pct = std::stod(valStr);
        return pct / 100.0; // convert from percent to decimal
    } catch(const std::exception &) {
        return std::nullopt;
    }
}

bool FredRateLoader::fetchRates() {
    auto r1 = fetchRate("DGS1MO");
    auto r3 = fetchRate("DGS3MO");
    auto r6 = fetchRate("DGS6MO");
    if (r1 && r3 && r6) {
        data_.rate1M = *r1;
        data_.rate3M = *r3;
        data_.rate6M = *r6;
        data_.fetched = std::chrono::system_clock::now();
        data_.valid = true;
        return true;
    }
    return false;
}

std::optional<double> FredRateLoader::get_rate_for_expiry(int days_to_expiry) {
    if (isStale()) {
        fetchRates();
    }
    if (!data_.valid) return std::nullopt;

    if (days_to_expiry <= 30) return data_.rate1M;
    if (days_to_expiry <= 90) return data_.rate3M;
    return data_.rate6M;
}

