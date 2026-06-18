import { createContext, useContext, useState, useEffect } from "react";
import { getCsrfToken, refreshCsrfToken } from "../utils/csrf";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
	const [user, setUser] = useState(null);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		checkCurrentUser();
	}, []);

	const checkCurrentUser = async () => {
		try {
			const response = await fetch("/api/current_user");
			const data = await response.json();
			if (data.logged_in) {
				setUser(data.user);
			}
		} catch (err) {
			console.error("Failed to check user status");
		} finally {
			setLoading(false);
		}
	};

	const login = (userData) => {
		setUser(userData);
	};

	const logout = async () => {
		try {
			await fetch("/users/sign_out", {
				method: "DELETE",
				headers: {
					"X-CSRF-Token": getCsrfToken(),
				},
			});
			setUser(null);
			await refreshCsrfToken();
		} catch (err) {
			console.error("Logout failed");
		}
	};

	return (
		<AuthContext.Provider value={{ user, loading, login, logout }}>
			{children}
		</AuthContext.Provider>
	);
}

export function useAuth() {
	const context = useContext(AuthContext);
	if (!context) {
		throw new Error("useAuth must be used within an AuthProvider");
	}
	return context;
}
