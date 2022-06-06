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
        return "It is public.";
    }

    @GetMapping("/private")
    public String getPrivateString(HttpServletRequest request) {
        return request.getHeader("X-Credential-Username") + ", it is private.";
    }
}