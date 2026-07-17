import { useState } from "react";
import { Link as RouterLink } from "react-router-dom";
import {
    Box,
    Button,
    Container,
    TextField,
    Typography,
    Alert,
    Paper,
    CircularProgress,
    Link,
} from "@mui/material";
import { useAuth } from "../contexts/AuthContext";
import { getCsrfToken, refreshCsrfToken } from "../utils/csrf";

export default function Login() {
    const { login } = useAuth();
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setLoading(true);

        try {
            const response = await fetch("/users/sign_in", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": getCsrfToken(),
                },
                body: JSON.stringify({
                    user: { email, password },
                }),
            });

            const data = await response.json();

            if (response.ok) {
                // Devise rotates the session CSRF token on sign-in; sync the
                // meta tag so later non-GET requests (including sign-out)
                // don't fail CSRF.
                await refreshCsrfToken();
                login(data.data);
            } else {
                setError(data.status?.message || "Invalid email or password");
            }
        } catch (err) {
            setError("An error occurred. Please try again.");
        } finally {
            setLoading(false);
        }
    };

    return (
        <Container maxWidth="sm" sx={{ px: { xs: 2, sm: 3 } }}>
            <Box sx={{ mt: { xs: 5, sm: 8 }, mb: 4 }}>
                <Paper elevation={3} sx={{ p: { xs: 2.5, sm: 4 } }}>
                    <Box sx={{ textAlign: "center", mb: 3 }}>
                        <img
                            src="/logo-green.png"
                            alt="Earthkin Nature School"
                            style={{ maxWidth: "100%", height: "auto", maxHeight: 80 }}
                        />
                    </Box>
                    <Typography
                        variant="h6"
                        component="h1"
                        gutterBottom
                        align="center"
                        color="text.secondary"
                    >
                        Earthkin Portal
                    </Typography>

                    <Box component="form" onSubmit={handleSubmit}>
                        <TextField
                            fullWidth
                            label="Email"
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            margin="normal"
                            required
                            autoComplete="email"
                            autoFocus
                        />
                        <TextField
                            fullWidth
                            label="Password"
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            margin="normal"
                            required
                            autoComplete="current-password"
                        />
                        <Button
                            type="submit"
                            fullWidth
                            variant="contained"
                            size="large"
                            disabled={loading}
                            sx={{ mt: 3, mb: 2 }}
                        >
                            <span style={{ visibility: loading ? "hidden" : "visible" }}>
                                Sign In
                            </span>
                            {loading && (
                                <CircularProgress
                                    size={24}
                                    sx={{ position: "absolute" }}
                                />
                            )}
                        </Button>
                        {error && (
                            <Alert severity="error" sx={{ mb: 2 }}>
                                {error}
                            </Alert>
                        )}
                        <Box sx={{ textAlign: "center", mt: 2 }}>
                            <Link component={RouterLink} to="/forgot-password" underline="hover">
                                Forgot Password?
                            </Link>
                        </Box>
                    </Box>
                </Paper>
            </Box>
        </Container>
    );
}
