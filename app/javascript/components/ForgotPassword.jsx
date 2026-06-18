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
import { getCsrfToken } from "../utils/csrf";

export default function ForgotPassword() {
    const [email, setEmail] = useState("");
    const [error, setError] = useState("");
    const [success, setSuccess] = useState(false);
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setSuccess(false);
        setLoading(true);

        try {
            const response = await fetch("/users/password", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": getCsrfToken(),
                },
                body: JSON.stringify({
                    user: { email },
                }),
            });

            const data = await response.json();

            if (response.ok) {
                setSuccess(true);
                setEmail("");
            } else {
                setError(data.status?.message || "Unable to send reset instructions");
            }
        } catch (err) {
            setError("An error occurred. Please try again.");
        } finally {
            setLoading(false);
        }
    };

    return (
        <Container maxWidth="sm">
            <Box sx={{ mt: 8 }}>
                <Paper elevation={3} sx={{ p: 4 }}>
                    <Box sx={{ textAlign: "center", mb: 3 }}>
                        <img
                            src="/assets/Earthkin Nature School Logo H-Grn.png"
                            alt="Earthkin Nature School"
                            style={{ maxWidth: "100%", height: "auto", maxHeight: 80 }}
                        />
                    </Box>
                    <Typography
                        variant="h5"
                        component="h1"
                        gutterBottom
                        align="center"
                    >
                        Forgot Password
                    </Typography>
                    <Typography
                        variant="body2"
                        color="text.secondary"
                        align="center"
                        sx={{ mb: 3 }}
                    >
                        Enter your email address and we'll send you instructions to reset your password.
                    </Typography>

                    {success ? (
                        <Box>
                            <Alert severity="success" sx={{ mb: 2 }}>
                                Password reset instructions have been sent to your email address.
                            </Alert>
                            <Box sx={{ textAlign: "center", mt: 3 }}>
                                <Link component={RouterLink} to="/login" underline="hover">
                                    Back to Sign In
                                </Link>
                            </Box>
                        </Box>
                    ) : (
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
                            <Button
                                type="submit"
                                fullWidth
                                variant="contained"
                                size="large"
                                disabled={loading}
                                sx={{ mt: 3, mb: 2 }}
                            >
                                <span style={{ visibility: loading ? "hidden" : "visible" }}>
                                    Send Reset Instructions
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
                                <Link component={RouterLink} to="/login" underline="hover">
                                    Back to Sign In
                                </Link>
                            </Box>
                        </Box>
                    )}
                </Paper>
            </Box>
        </Container>
    );
}
