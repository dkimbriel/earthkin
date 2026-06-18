import { useState, useEffect } from "react";
import { useSearchParams, useNavigate, Link as RouterLink } from "react-router-dom";
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

export default function ResetPassword() {
    const [searchParams] = useSearchParams();
    const navigate = useNavigate();
    const [password, setPassword] = useState("");
    const [passwordConfirmation, setPasswordConfirmation] = useState("");
    const [error, setError] = useState("");
    const [success, setSuccess] = useState(false);
    const [loading, setLoading] = useState(false);
    const [resetToken, setResetToken] = useState("");

    useEffect(() => {
        const token = searchParams.get("reset_password_token");
        if (token) {
            setResetToken(token);
        } else {
            setError("Invalid or missing reset token");
        }
    }, [searchParams]);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setSuccess(false);

        if (password !== passwordConfirmation) {
            setError("Passwords do not match");
            return;
        }

        if (password.length < 6) {
            setError("Password must be at least 6 characters");
            return;
        }

        setLoading(true);

        try {
            const response = await fetch("/users/password", {
                method: "PUT",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": getCsrfToken(),
                },
                body: JSON.stringify({
                    user: {
                        reset_password_token: resetToken,
                        password: password,
                        password_confirmation: passwordConfirmation,
                    },
                }),
            });

            const data = await response.json();

            if (response.ok) {
                setSuccess(true);
                setTimeout(() => {
                    navigate("/login");
                }, 3000);
            } else {
                setError(
                    data.errors?.join(", ") ||
                    data.status?.message ||
                    "Unable to reset password"
                );
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
                        Reset Password
                    </Typography>
                    <Typography
                        variant="body2"
                        color="text.secondary"
                        align="center"
                        sx={{ mb: 3 }}
                    >
                        Enter your new password below.
                    </Typography>

                    {success ? (
                        <Box>
                            <Alert severity="success" sx={{ mb: 2 }}>
                                Password has been reset successfully! Redirecting to login...
                            </Alert>
                        </Box>
                    ) : (
                        <Box component="form" onSubmit={handleSubmit}>
                            <TextField
                                fullWidth
                                label="New Password"
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                margin="normal"
                                required
                                autoComplete="new-password"
                                autoFocus
                                helperText="Must be at least 6 characters"
                            />
                            <TextField
                                fullWidth
                                label="Confirm New Password"
                                type="password"
                                value={passwordConfirmation}
                                onChange={(e) => setPasswordConfirmation(e.target.value)}
                                margin="normal"
                                required
                                autoComplete="new-password"
                            />
                            <Button
                                type="submit"
                                fullWidth
                                variant="contained"
                                size="large"
                                disabled={loading || !resetToken}
                                sx={{ mt: 3, mb: 2 }}
                            >
                                <span style={{ visibility: loading ? "hidden" : "visible" }}>
                                    Reset Password
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