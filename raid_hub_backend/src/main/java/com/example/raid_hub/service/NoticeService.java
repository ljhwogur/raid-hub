package com.example.raid_hub.service;

import com.example.raid_hub.entity.Notice;
import com.example.raid_hub.repository.NoticeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NoticeService {
    private final NoticeRepository noticeRepository;

    @Transactional(readOnly = true)
    public String getNoticeContent() {
        Notice notice = noticeRepository.findFirstByOrderByIdAsc();
        return (notice != null) ? notice.getContent() : "공지사항이 없습니다.";
    }

    @Transactional
    public void updateNotice(String newContent) {
        Notice notice = noticeRepository.findFirstByOrderByIdAsc();
        if (notice == null) {
            notice = Notice.builder().content(newContent).build();
        } else {
            notice.setContent(newContent);
        }
        noticeRepository.save(notice);
    }
}
