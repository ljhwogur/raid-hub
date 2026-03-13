package com.example.raid_hub.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RateLimitInterceptor implements HandlerInterceptor {

    // IP별로 버킷을 저장하는 저장소
    private final Map<String, Bucket> generalBuckets = new ConcurrentHashMap<>();
    private final Map<String, Bucket> logBuckets = new ConcurrentHashMap<>();

    // 전체 API용 버킷 생성 (1분당 100회)
    private Bucket createGeneralBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
                .build();
    }

    // 로그 전용 버킷 생성 (1분당 30회)
    private Bucket createLogBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.classic(30, Refill.greedy(30, Duration.ofMinutes(1))))
                .build();
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        String ip = getClientIP(request);
        String path = request.getRequestURI();

        // 1. 로그 수집 API 전용 제한 체크
        if (path.startsWith("/api/stats/log")) {
            Bucket logBucket = logBuckets.computeIfAbsent(ip, k -> createLogBucket());
            if (!logBucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.getWriter().write("Too many logging requests. Please wait a minute.");
                return false;
            }
        }

        // 2. 전체 API 공통 제한 체크
        Bucket generalBucket = generalBuckets.computeIfAbsent(ip, k -> createGeneralBucket());
        if (!generalBucket.tryConsume(1)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.getWriter().write("Too many requests. Please wait a minute.");
            return false;
        }

        return true;
    }

    private String getClientIP(HttpServletRequest request) {
        String xfHeader = request.getHeader("X-Forwarded-For");
        if (xfHeader == null) {
            return request.getRemoteAddr();
        }
        return xfHeader.split(",")[0];
    }
}
