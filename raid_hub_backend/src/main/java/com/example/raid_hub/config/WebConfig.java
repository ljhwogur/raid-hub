package com.example.raid_hub.config;

import java.nio.file.Path;
import java.nio.file.Paths;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class WebConfig implements WebMvcConfigurer {

  private final RateLimitInterceptor rateLimitInterceptor;

  @Value("${file.upload-dir}")
  private String uploadDir;

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(rateLimitInterceptor)
        .addPathPatterns("/api/**"); // 모든 API 경로에 도배 방지 적용
  }

  @Override
  public void addResourceHandlers(ResourceHandlerRegistry registry) {
    Path uploadPath = Paths.get(uploadDir).toAbsolutePath().normalize();
    String resourceLocation = uploadPath.toUri().toString();
    
    if (!resourceLocation.endsWith("/")) {
        resourceLocation += "/";
    }

    // /uploads/cheatsheets/** 요청이 오면 실제 로컬 폴더에서 파일을 찾음
    registry.addResourceHandler("/uploads/cheatsheets/**").addResourceLocations(resourceLocation);
  }
}
