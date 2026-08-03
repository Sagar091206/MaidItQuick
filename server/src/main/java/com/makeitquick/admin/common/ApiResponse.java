package com.makeitquick.admin.common;

import java.time.Instant;

public record ApiResponse<T>(boolean success, String message, T data, Instant timestamp) {

  public static <T> ApiResponse<T> ok(T data) {
    return new ApiResponse<>(true, "OK", data, Instant.now());
  }

  public static <T> ApiResponse<T> ok(String message, T data) {
    return new ApiResponse<>(true, message, data, Instant.now());
  }

  public static ApiResponse<Void> ok(String message) {
    return new ApiResponse<>(true, message, null, Instant.now());
  }

  public static <T> ApiResponse<T> created(T data) {
    return new ApiResponse<>(true, "Created", data, Instant.now());
  }
}
