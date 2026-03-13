package com.example.raid_hub.repository;

import com.example.raid_hub.entity.AdminPost;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface AdminPostRepository extends JpaRepository<AdminPost, Long> {
    List<AdminPost> findAllByOrderByCreatedAtDesc();
}
