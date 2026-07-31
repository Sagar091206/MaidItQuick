package com.makeitquick.worker;
import com.makeitquick.security.UserAccount; import java.util.*; import org.springframework.data.jpa.repository.JpaRepository;
public interface WorkerProfileRepository extends JpaRepository<WorkerProfile,Long>{Optional<WorkerProfile> findByUser(UserAccount user);}
