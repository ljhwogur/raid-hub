package com.example.raid_hub.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http, ObjectMapper objectMapper)
      throws Exception {
    http.cors(cors -> cors.configurationSource(corsConfigurationSource())) // CORS 설정 적용
        .csrf(csrf -> csrf.disable()) // CSRF 비활성화
        .authorizeHttpRequests(
            authorizeRequests ->
                authorizeRequests
                    .requestMatchers(HttpMethod.OPTIONS, "/**")
                    .permitAll()
                    .requestMatchers(HttpMethod.POST, "/api/users/register")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/users/check-username/**")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/youtube/playlist-items")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/notice").permitAll()
                    .requestMatchers(HttpMethod.PUT, "/api/notice").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.POST, "/api/videos").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.DELETE, "/api/videos/**")
                    .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.POST, "/api/blocked-videos")
                    .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.DELETE, "/api/blocked-videos/**")
                    .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.POST, "/api/cheatsheets")
                    .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.DELETE, "/api/cheatsheets/**")
                    .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.GET, "/api/blocked-videos")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/cheatsheets")
                    .permitAll()
                    .requestMatchers("/uploads/cheatsheets/**")
                    .permitAll() // Allow everyone to see the images
                    .requestMatchers("/error")
                    .permitAll() // Allow Spring Boot's error handler
                    .requestMatchers(HttpMethod.GET, "/api/**")
                    .permitAll()
                    .anyRequest()
                    .authenticated())
        .exceptionHandling(
            exceptionHandling ->
                exceptionHandling
                    .authenticationEntryPoint(
                        (request, response, authException) -> {
                          // 모든 요청에 대해 401 반환 (REST API 이므로 리다이렉트 금지)
                          response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                          response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                          response.setCharacterEncoding("UTF-8");
                          Map<String, Object> responseMap = new HashMap<>();
                          responseMap.put("success", false);
                          responseMap.put("message", "인증이 필요합니다.");
                          response
                              .getWriter()
                              .write(objectMapper.writeValueAsString(responseMap));
                        })
                    .accessDeniedHandler(
                        (request, response, accessDeniedException) -> {
                          // 권한 부족 시 403 반환
                          response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                          response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                          response.setCharacterEncoding("UTF-8");
                          Map<String, Object> responseMap = new HashMap<>();
                          responseMap.put("success", false);
                          responseMap.put("message", "접근 권한이 없습니다.");
                          response.getWriter().write(objectMapper.writeValueAsString(responseMap));
                        }))
        .formLogin(
            formLogin ->
                formLogin
                    .permitAll()
                    .successHandler(
                        (request, response, authentication) -> {
                          response.setStatus(HttpServletResponse.SC_OK);
                          response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                          response.setCharacterEncoding("UTF-8");
                          Map<String, Object> responseMap = new HashMap<>();
                          responseMap.put("success", true);
                          responseMap.put("message", "성공적으로 로그인하였습니다.");
                          responseMap.put("username", authentication.getName());
                          responseMap.put("sessionId", request.getSession().getId());
                          response.getWriter().write(objectMapper.writeValueAsString(responseMap));
                        })
                    .failureHandler(
                        (request, response, exception) -> {
                          response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                          response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                          response.setCharacterEncoding("UTF-8");
                          Map<String, Object> responseMap = new HashMap<>();
                          responseMap.put("success", false);

                          if (exception instanceof DisabledException) {
                            responseMap.put("message", "아이디는 관리자 인증을 받은 후 사용하실 수 있습니다.");
                          } else {
                            responseMap.put("message", exception.getMessage());
                          }

                          response.getWriter().write(objectMapper.writeValueAsString(responseMap));
                        }));

    return http.build();
  }

  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    // 플러터 웹의 모든 출처 허용 (Credentials 포함 시 AllowedOriginPatterns 사용 필수)
    config.setAllowedOriginPatterns(Arrays.asList(
        "http://localhost:*", 
        "http://127.0.0.1:*",
        "http://20.89.237.161*"
    ));
    config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(Arrays.asList("*"));
    config.setExposedHeaders(Arrays.asList("Set-Cookie"));
    config.setAllowCredentials(true); // 쿠키 허용

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }
}
