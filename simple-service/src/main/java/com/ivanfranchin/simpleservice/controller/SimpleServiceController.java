package com.ivanfranchin.simpleservice.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class SimpleServiceController {

    @GetMapping("/public")
    public String getPublicString() {
        return "It is public.";
    }

    @GetMapping("/private")
    public String getPrivateString(HttpServletRequest request) {
        return request.getHeader("X-Credential-Identifier") + ", it is private.";
    }
}