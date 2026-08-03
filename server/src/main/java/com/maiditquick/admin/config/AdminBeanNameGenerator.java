package com.maiditquick.admin.config;

import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.beans.factory.support.BeanDefinitionRegistry;
import org.springframework.context.annotation.AnnotationBeanNameGenerator;

/**
 * Disambiguates bean names for the admin module. Both the mobile backend
 * (com.makeitquick.*) and the admin module (com.maiditquick.admin.*) define
 * components with identical simple names (SecurityConfig, AuthService, JwtService,
 * BookingController, ...). When both modules live in the same Spring context the
 * default simple-name based bean names would collide; prefixing admin beans with
 * {@code adminModule} keeps them distinct while leaving the mobile module
 * untouched. The prefix intentionally cannot equal a name the mobile module would
 * produce on its own (mobile classes named {@code Admin*} generate {@code admin*}
 * bean names), which is why a single word like {@code admin} is not enough.
 */
public class AdminBeanNameGenerator extends AnnotationBeanNameGenerator {

    public static final String PREFIX = "adminModule";

    @Override
    protected String buildDefaultBeanName(BeanDefinition definition) {
        String name = super.buildDefaultBeanName(definition);
        return name.isEmpty()
                ? PREFIX
                : PREFIX + Character.toUpperCase(name.charAt(0)) + name.substring(1);
    }
}
