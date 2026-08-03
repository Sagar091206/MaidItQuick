package com.makeitquick.admin.config;

import com.makeitquick.admin.auth.AuthExceptions;
import com.makeitquick.admin.auth.AuthExceptions.AccountDisabledException;
import com.makeitquick.admin.auth.AuthExceptions.InvalidCredentialsException;
import com.makeitquick.admin.auth.AuthExceptions.LoginLockedException;
import com.makeitquick.admin.common.NotFoundException;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice(basePackages = "com.makeitquick.admin")
public class AdminApiExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(AdminApiExceptionHandler.class);

  @ExceptionHandler(IllegalArgumentException.class)
  ResponseEntity<Map<String, Object>> invalid(IllegalArgumentException e) {
    return error(HttpStatus.BAD_REQUEST, e.getMessage());
  }

  @ExceptionHandler(InvalidCredentialsException.class)
  ResponseEntity<Map<String, Object>> invalidCredentials(InvalidCredentialsException e) {
    return error(HttpStatus.UNAUTHORIZED, e.getMessage());
  }

  @ExceptionHandler(AccountDisabledException.class)
  ResponseEntity<Map<String, Object>> accountDisabled(AccountDisabledException e) {
    return error(HttpStatus.FORBIDDEN, e.getMessage());
  }

  @ExceptionHandler(LoginLockedException.class)
  ResponseEntity<Map<String, Object>> loginLocked(LoginLockedException e) {
    return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
        .header(HttpHeaders.RETRY_AFTER, String.valueOf(e.retryAfterSeconds()))
        .body(base(HttpStatus.TOO_MANY_REQUESTS, e.getMessage()));
  }

  @ExceptionHandler(AuthExceptions.PasswordResetMailException.class)
  ResponseEntity<Map<String, Object>> resetMailFailure(AuthExceptions.PasswordResetMailException e) {
    return error(HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage());
  }

  @ExceptionHandler(AuthExceptions.InvalidResetTokenException.class)
  ResponseEntity<Map<String, Object>> invalidResetToken(AuthExceptions.InvalidResetTokenException e) {
    return error(HttpStatus.BAD_REQUEST, e.getMessage());
  }

  @ExceptionHandler(NotFoundException.class)
  ResponseEntity<Map<String, Object>> notFound(NotFoundException e) {
    return error(HttpStatus.NOT_FOUND, e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ResponseEntity<Map<String, Object>> validation(MethodArgumentNotValidException e) {
    Map<String, Object> body = base(HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed");
    Map<String, String> fields = new LinkedHashMap<>();
    for (FieldError fe : e.getBindingResult().getFieldErrors()) {
      fields.putIfAbsent(fe.getField(), fe.getDefaultMessage());
    }
    body.put("errors", fields);
    return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(body);
  }

  @ExceptionHandler(ConstraintViolationException.class)
  ResponseEntity<Map<String, Object>> constraints(ConstraintViolationException e) {
    Map<String, Object> body = base(HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed");
    Map<String, String> fields = new LinkedHashMap<>();
    e.getConstraintViolations().forEach(v -> fields.putIfAbsent(v.getPropertyPath().toString(), v.getMessage()));
    body.put("errors", fields);
    return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(body);
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  ResponseEntity<Map<String, Object>> conflict(DataIntegrityViolationException e) {
    return error(HttpStatus.CONFLICT, "Record conflicts with existing data or is still referenced by other records");
  }

  @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class,
      MissingServletRequestParameterException.class})
  ResponseEntity<Map<String, Object>> malformed(Exception e) {
    return error(HttpStatus.BAD_REQUEST, "Malformed request: " + e.getMessage());
  }

  @ExceptionHandler(AccessDeniedException.class)
  ResponseEntity<Map<String, Object>> denied(AccessDeniedException e) {
    return error(HttpStatus.FORBIDDEN, "Insufficient permissions");
  }

  @ExceptionHandler(NoResourceFoundException.class)
  ResponseEntity<Map<String, Object>> noRoute(NoResourceFoundException e) {
    return error(HttpStatus.NOT_FOUND, "Resource not found");
  }

  @ExceptionHandler(Exception.class)
  ResponseEntity<Map<String, Object>> fallback(Exception e) {
    log.error("Unhandled exception", e);
    return error(HttpStatus.INTERNAL_SERVER_ERROR, "Unexpected server error");
  }

  private Map<String, Object> base(HttpStatus s, String m) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("timestamp", Instant.now());
    body.put("success", false);
    body.put("status", s.value());
    body.put("message", m);
    return body;
  }

  private ResponseEntity<Map<String, Object>> error(HttpStatus s, String m) {
    return ResponseEntity.status(s).body(base(s, m));
  }
}
