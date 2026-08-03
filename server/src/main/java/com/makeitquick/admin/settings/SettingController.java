package com.makeitquick.admin.settings;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/v1/admin/settings")
public class SettingController {

  private final SettingRepository settings;
  private final AuditService audit;

  public SettingController(SettingRepository settings, AuditService audit) {
    this.settings = settings;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('SETTINGS_READ')")
  public ApiResponse<List<Setting>> list() {
    return ApiResponse.ok(settings.findAll());
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('SETTINGS_READ')")
  public ApiResponse<Setting> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
  public ApiResponse<Setting> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    String key = normalizeKey(body.key());
    if (settings.existsBySettingKey(key)) {
      throw new IllegalArgumentException("A setting with this key already exists");
    }
    Setting s = new Setting();
    s.setSettingKey(key);
    s.setSettingValue(body.value().trim());
    s.setDescription(body.description());
    Setting saved = settings.save(s);
    audit.record("SETTING_CREATED", "SETTINGS", String.valueOf(saved.getId()), null,
        "{\"key\":\"" + saved.getSettingKey() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
  public ApiResponse<Setting> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Setting s = find(id);
    String key = normalizeKey(body.key());
    if (settings.existsBySettingKeyAndIdNot(key, id)) {
      throw new IllegalArgumentException("A setting with this key already exists");
    }
    s.setSettingKey(key);
    s.setSettingValue(body.value().trim());
    s.setDescription(body.description());
    s.setUpdatedAt(Instant.now());
    Setting saved = settings.save(s);
    audit.record("SETTING_UPDATED", "SETTINGS", String.valueOf(id), null,
        "{\"key\":\"" + saved.getSettingKey() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('SETTINGS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    settings.delete(find(id));
    audit.record("SETTING_DELETED", "SETTINGS", String.valueOf(id), null, null, req);
  }

  private Setting find(long id) {
    return settings.findById(id).orElseThrow(() -> NotFoundException.of("Setting", id));
  }

  private String normalizeKey(String key) {
    return key.trim().toUpperCase().replace(' ', '_');
  }

  public record Upsert(
      @NotBlank @Pattern(regexp = "[A-Za-z0-9_.-]+") @Size(max = 120) String key,
      @NotBlank @Size(max = 2000) String value,
      @Size(max = 500) String description) {
  }
}
