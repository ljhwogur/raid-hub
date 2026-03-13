package com.example.raid_hub.service;

import com.example.raid_hub.entity.AdminPost;
import com.example.raid_hub.repository.AdminPostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminPostService {
    private final AdminPostRepository adminPostRepository;

    @Transactional(readOnly = true)
    public List<AdminPost> getAllPosts() {
        return adminPostRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional(readOnly = true)
    public AdminPost getPostById(Long id) {
        return adminPostRepository.findById(id).orElseThrow(() -> new RuntimeException("Post not found"));
    }

    @Transactional
    public AdminPost createPost(AdminPost post) {
        return adminPostRepository.save(post);
    }

    @Transactional
    public AdminPost updatePost(Long id, AdminPost postDetails) {
        AdminPost post = getPostById(id);
        post.setTitle(postDetails.getTitle());
        post.setContent(postDetails.getContent());
        return adminPostRepository.save(post);
    }

    @Transactional
    public void deletePost(Long id) {
        adminPostRepository.deleteById(id);
    }
}
