INSERT INTO users (username, password, role, enabled)
VALUES ('admin', '$2a$10$YsvAvc7CUJQ1t8ybSjxvD.vCPjaKqREWnx9JFIYU0vsEEghZNElDO', 'ADMIN', true)
ON CONFLICT (username) DO NOTHING;

