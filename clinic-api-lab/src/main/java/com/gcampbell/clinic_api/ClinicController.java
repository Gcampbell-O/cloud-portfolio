package com.gcampbell.clinic_api;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/clinics")
public class ClinicController {

    private final JdbcClient jdbc;

    public ClinicController(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Clinic> all() {
        return jdbc.sql("SELECT Id, Name, City, Services FROM dbo.Clinics ORDER BY Id")
            .query(Clinic.class)
            .list();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Clinic> byId(@PathVariable int id) {
        return jdbc.sql("SELECT Id, Name, City, Services FROM dbo.Clinics WHERE Id = :id")
            .param("id", id)
            .query(Clinic.class)
            .optional()
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }
}
