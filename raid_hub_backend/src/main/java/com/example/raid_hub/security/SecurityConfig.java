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
        .authorizeHttpRequests(
            authorizeRequests ->
                authorizeRequests
                    .requestMatchers(HttpMethod.OPTIONS, "/**")
                    .permitAll() // Allow all OPTIONS requests
                    .requestMatchers(HttpMethod.POST, "/api/users/register")
                    .permitAll() // Allow user registration without authentication
                    .requestMatchers(HttpMethod.GET, "/api/users/check-username/**")
                    .permitAll() // Allow username check without authentication
                    .requestMatchers(HttpMethod.GET, "/api/youtube/playlist-items")
                    .permitAll() // Allow playlist items without authentication
                    .requestMatchers(HttpMethod.POST, "/api/videos")
                    .hasRole("ADMIN") // Only ADMIN can POST to /api/videos
                    .requestMatchers(HttpMethod.GET, "/api/**")
                    .permitAll() // Allow GET /api requests
                    .anyRequest()
                    .authenticated() // All other requests require authentication
            )
        .formLogin(
            formLogin ->
                formLogin
                    .permitAll() // Allow everyone to access the login page
                    .successHandler(
                        (request, response, authentication) -> {
                          response.setStatus(HttpServletResponse.SC_OK);
                          response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                          response.setCharacterEncoding("UTF-8");
                          Map<String, Object> responseMap = new HashMap<>();
                          responseMap.put("success", true);
                          responseMap.put("message", "성공적으로 로그인하였습니다.");
                          responseMap.put("username", authentication.getName());
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
                        }))
        .csrf(csrf -> csrf.disable()); // Temporarily disable CSRF for easier testing

    return http.build();
  }

  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(Arrays.asList("http://localhost:53551"));
    config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(Arrays.asList("*"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }
}
