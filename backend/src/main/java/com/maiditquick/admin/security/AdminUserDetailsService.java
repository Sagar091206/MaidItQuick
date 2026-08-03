package com.maiditquick.admin.security;
import com.maiditquick.admin.admin.*;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.*;
import org.springframework.stereotype.Service;

@Service
public class AdminUserDetailsService implements UserDetailsService {
  private final AdminRepository admins; public AdminUserDetailsService(AdminRepository admins) { this.admins=admins; }
  public UserDetails loadUserByUsername(String email) { Admin a=admins.findByEmailIgnoreCase(email).orElseThrow(()->new UsernameNotFoundException("Admin not found")); return User.withUsername(a.getEmail()).password(a.getPasswordHash()).disabled(!a.isEnabled()).authorities(a.getRole().getPermissions().stream().map(p->new SimpleGrantedAuthority(p.getCode())).toList()).build(); }
}
