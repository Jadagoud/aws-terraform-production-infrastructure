const express = require("express");
const cors = require("cors");
require("dotenv").config();

const pool = require("./db");

const app = express();

const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get("/api/health", (req, res) => {
    res.status(200).json({
        status: "UP",
        message: "Backend is running"
    });
});

// Database health check
app.get("/api/db-health", async (req, res) => {
    try {
        const [rows] = await pool.query("SELECT 1 AS result");

        res.status(200).json({
            status: "UP",
            database: "MySQL",
            result: rows[0].result
        });
    } catch (error) {
        console.error("Database connection failed:", error.message);

        res.status(500).json({
            status: "DOWN",
            database: "MySQL",
            error: error.message
        });
    }
});
// Get all users
app.get("/api/users", async (req, res) => {
    try {
        const [rows] = await pool.query(
            "SELECT id, name, email, created_at FROM users ORDER BY id"
        );

        res.status(200).json(rows);
    } catch (error) {
        console.error("Failed to fetch users:", error.message);

        res.status(500).json({
            error: "Failed to fetch users"
        });
    }
});
// Create a new user
app.post("/api/users", async (req, res) => {
    try {
        const { name, email } = req.body;

        if (!name || !email) {
            return res.status(400).json({
                error: "Name and email are required"
            });
        }

        const [result] = await pool.query(
            "INSERT INTO users (name, email) VALUES (?, ?)",
            [name, email]
        );

        res.status(201).json({
            message: "User created successfully",
            user: {
                id: result.insertId,
                name,
                email
            }
        });
    } catch (error) {
        console.error("Failed to create user:", error.message);

        res.status(500).json({
            error: "Failed to create user"
        });
    }
});
// Start server
app.listen(PORT, () => {
    console.log(`Backend server running on port ${PORT}`);
});
