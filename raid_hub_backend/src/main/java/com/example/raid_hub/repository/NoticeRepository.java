package com.example.raid_hub.repository;

import com.example.raid_hub.entity.Notice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface NoticeRepository extends JpaRepository<Notice, Long> {
    // 항상 최신 공지 하나만 사용하므로 findFirstByOrderByIdDesc 등을 활용 가능
    Notice findFirstByOrderByIdAsc();
}
