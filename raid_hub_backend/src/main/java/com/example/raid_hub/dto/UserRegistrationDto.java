package com.example.raid_hub.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserRegistrationDto {

  @NotBlank(message = "username은 필수입니다")
  @Size(min = 7, max = 20, message = "username은 7자 이상 20자 이하여야 합니다")
  @Pattern(regexp = "^[a-zA-Z0-9_-]+$", message = "username은 알파벳, 숫자, _, -만 사용 가능합니다")
  private String username;

  @NotBlank(message = "password는 필수입니다")
  @Size(min = 8, max = 30, message = "password는 8자 이상 30자 이하여야 합니다")
  private String password;
}
