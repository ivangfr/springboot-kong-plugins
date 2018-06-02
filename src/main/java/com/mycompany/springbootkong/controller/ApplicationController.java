package com.mycompany.springbootkong.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api")
public class ApplicationController {

    @GetMapping("/public")
    public ResponseEntity<String> getPublicString() {
        return ResponseEntity.ok("It is public.\n");
    }

    @GetMapping("/private")
    public ResponseEntity<String> getPrivateString(HttpServletRequest request) {
        String username = request.getHeader("X-Credential-Username");
        String response = username + ", it is private.\n";
        return ResponseEntity.ok(response);
    }

}