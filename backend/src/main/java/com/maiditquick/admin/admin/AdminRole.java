package com.maiditquick.admin.admin;

import jakarta.persistence.*;
import lombok.*;
import java.util.*;

@Entity @Table(name = "admin_roles") @Getter @Setter @NoArgsConstructor
public class AdminRole {
  @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
  @Column(nullable = false, unique = true) private String code;
  @Column(nullable = false) private String name;
  @ManyToMany(fetch = FetchType.EAGER) @JoinTable(name = "admin_role_permissions", joinColumns = @JoinColumn(name = "role_id"), inverseJoinColumns = @JoinColumn(name = "permission_id")) private Set<AdminPermission> permissions = new HashSet<>();
}
