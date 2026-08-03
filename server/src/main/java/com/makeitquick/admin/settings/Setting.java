package com.makeitquick.admin.settings;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity
@Table(name = "settings")
@Getter
@Setter
@NoArgsConstructor
public class Setting {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(nullable = false, unique = true)
  private String settingKey;
  @Column(nullable = false, length = 2000)
  private String settingValue;
  @Column(length = 500)
  private String description;
  @Column(name = "updated_at")
  private Instant updatedAt;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
