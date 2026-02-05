package com.example.raid_hub;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import lombok.RequiredArgsConstructor;

import java.util.List;

@Service
@RequiredArgsConstructor
public class RaidVideoService {

    private final RaidVideoRepository raidVideoRepository;

    @Transactional
    public RaidVideo createVideo(RaidVideo video) {
        return raidVideoRepository.save(video);
    }

    @Transactional(readOnly = true)
    public List<RaidVideo> getAllVideos() {
        return raidVideoRepository.findAll();
    }
}
