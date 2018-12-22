package com.mycompany.springbootkong.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import javax.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api")
public class PublicPrivateController {

    @ResponseStatus(HttpStatus.OK)
    @GetMapping("/public")
    public String getPublicString() {
        return "It is public.\n";
    }

    @ResponseStatus(HttpStatus.OK)
    @GetMapping("/private")
    public String getPrivateString(HttpServletRequest request) {
        String username = request.getHeader("X-Credential-Username");
        return String.format("%s, it is private.\n", username);
    }

}