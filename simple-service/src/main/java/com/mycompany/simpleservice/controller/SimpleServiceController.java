package com.mycompany.simpleservice.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api")
public class SimpleServiceController {

    @GetMapping("/public")
    public String getPublicString() {
        return "It is public.\n";
    }

    @GetMapping("/private")
    public String getPrivateString(HttpServletRequest request) {
        String username = request.getHeader("X-Credential-Username");
        return username + ", it is private.\n";
    }

}