package com.example.raid_hub.controller;

import com.example.raid_hub.entity.AdminPost;
import com.example.raid_hub.service.AdminPostService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/admin-posts")
@RequiredArgsConstructor
public class AdminPostController {
    private final AdminPostService adminPostService;

    @GetMapping
    public List<AdminPost> getAllPosts() {
        return adminPostService.getAllPosts();
    }

    @GetMapping("/{id}")
    public AdminPost getPostById(@PathVariable Long id) {
        return adminPostService.getPostById(id);
    }

    @PostMapping
    public AdminPost createPost(@RequestBody AdminPost post) {
        return adminPostService.createPost(post);
    }

    @PutMapping("/{id}")
    public AdminPost updatePost(@PathVariable Long id, @RequestBody AdminPost post) {
        return adminPostService.updatePost(id, post);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePost(@PathVariable Long id) {
        adminPostService.deletePost(id);
        return ResponseEntity.ok().build();
    }
}
