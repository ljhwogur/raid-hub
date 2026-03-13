package com.example.raid_hub.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class PasswordChangeDto {
    @NotBlank
    private String currentPassword;

    @NotBlank
    private String newPassword;
}
