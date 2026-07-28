package com.makeitquick;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class MakeItQuickApplication { public static void main(String[] args) { SpringApplication.run(MakeItQuickApplication.class, args); } }
