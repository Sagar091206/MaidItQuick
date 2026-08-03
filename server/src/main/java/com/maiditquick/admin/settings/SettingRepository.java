package com.maiditquick.admin.settings;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SettingRepository extends JpaRepository<Setting, Long> {
  Optional<Setting> findBySettingKey(String key);
  boolean existsBySettingKey(String key);
  boolean existsBySettingKeyAndIdNot(String key, Long id);
}
