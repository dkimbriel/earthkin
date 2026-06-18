import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { ThemeProvider } from "@mui/material/styles";
import { CssBaseline, Box, Typography } from "@mui/material";
import theme from "../theme";
import { AuthProvider, useAuth } from "../contexts/AuthContext";
import ErrorBoundary from "./ErrorBoundary";
import Login from "./Login";
import ForgotPassword from "./ForgotPassword";
import ResetPassword from "./ResetPassword";
import Dashboard from "./Dashboard";
import PublicEnrollmentPage from "./pages/PublicEnrollmentPage";

function ProtectedRoute({ children }) {
	const { user, loading } = useAuth();

	if (loading) {
		return (
			<Box
				sx={{
					display: "flex",
					justifyContent: "center",
					alignItems: "center",
					minHeight: "100vh",
				}}
			>
				<Typography>Loading...</Typography>
			</Box>
		);
	}

	return user ? children : <Navigate to="/login" replace />;
}

function PublicRoute({ children }) {
	const { user, loading } = useAuth();

	if (loading) {
		return (
			<Box
				sx={{
					display: "flex",
					justifyContent: "center",
					alignItems: "center",
					minHeight: "100vh",
				}}
			>
				<Typography>Loading...</Typography>
			</Box>
		);
	}

	return !user ? children : <Navigate to="/" replace />;
}

function AppContent() {
	return (
		<Routes>
			<Route path="/login" element={
				<PublicRoute>
					<Login />
				</PublicRoute>
			} />
			<Route path="/forgot-password" element={
				<PublicRoute>
					<ForgotPassword />
				</PublicRoute>
			} />
			<Route path="/reset-password" element={
				<PublicRoute>
					<ResetPassword />
				</PublicRoute>
			} />
			<Route path="/enroll" element={<PublicEnrollmentPage />} />
			<Route path="/*" element={
				<ProtectedRoute>
					<Dashboard />
				</ProtectedRoute>
			} />
		</Routes>
	);
}

export default function App() {
	return (
		<ErrorBoundary>
			<ThemeProvider theme={theme}>
				<CssBaseline />
				<BrowserRouter>
					<AuthProvider>
						<AppContent />
					</AuthProvider>
				</BrowserRouter>
			</ThemeProvider>
		</ErrorBoundary>
	);
}
