package com.makeitquick.operations;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface ServiceAreaRepository extends JpaRepository<ServiceArea,Long>{Optional<ServiceArea> findByPinCode(String pinCode);}
