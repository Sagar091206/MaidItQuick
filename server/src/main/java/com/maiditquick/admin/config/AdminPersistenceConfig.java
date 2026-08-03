package com.maiditquick.admin.config;

import com.zaxxer.hikari.HikariDataSource;
import jakarta.persistence.EntityManagerFactory;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.PlatformTransactionManager;

import java.util.HashMap;
import java.util.Map;

/**
 * Secondary persistence unit for the admin module.
 *
 * The merged application is a single Spring Boot process that serves both the
 * mobile app (primary datasource, com.makeitquick.*) and the admin web module
 * (secondary datasource, com.maiditquick.admin.*). Until Phase 2 unifies the
 * schema, each module keeps its own database, entity manager and repositories.
 *
 * Bean names use the {@link AdminBeanNameGenerator} prefix so the many
 * same-named components in the two modules do not collide.
 */
@Configuration
@EnableJpaRepositories(
        basePackages = "com.maiditquick.admin",
        entityManagerFactoryRef = "adminEntityManagerFactory",
        transactionManagerRef = "adminTransactionManager",
        nameGenerator = AdminBeanNameGenerator.class)
public class AdminPersistenceConfig {

    @Bean(name = "adminDataSource")
    public DataSource adminDataSource(
            @Value("${admin.datasource.url}") String url,
            @Value("${admin.datasource.username:}") String username,
            @Value("${admin.datasource.password:}") String password) {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(url);
        if (username != null && !username.isBlank()) {
            ds.setUsername(username);
        }
        if (password != null && !password.isBlank()) {
            ds.setPassword(password);
        }
        ds.setMaximumPoolSize(10);
        return ds;
    }

    @Bean(name = "adminEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean adminEntityManagerFactory(
            @Qualifier("adminDataSource") DataSource dataSource,
            @Value("${admin.jpa.hibernate.ddl-auto:update}") String ddlAuto) {
        LocalContainerEntityManagerFactoryBean em = new LocalContainerEntityManagerFactoryBean();
        em.setDataSource(dataSource);
        em.setPackagesToScan("com.maiditquick.admin");
        em.setPersistenceUnitName("admin");
        em.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
        Map<String, Object> props = new HashMap<>();
        props.put("hibernate.hbm2ddl.auto", ddlAuto);
        em.setJpaPropertyMap(props);
        return em;
    }

    @Bean(name = "adminTransactionManager")
    public PlatformTransactionManager adminTransactionManager(
            @Qualifier("adminEntityManagerFactory") EntityManagerFactory factory) {
        return new JpaTransactionManager(factory);
    }
}
