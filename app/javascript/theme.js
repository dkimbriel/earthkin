import { createTheme } from "@mui/material/styles";

const theme = createTheme({
		palette: {
				primary: {
						main: "#2e7d32",
				},
		},
		typography: {
				fontFamily: "Helvetica, Arial, sans-serif",
		},
		components: {
				MuiButton: {
						styleOverrides: {
								root: {
										textTransform: "none",
								},
						},
				},
				MuiAppBar: {
						styleOverrides: {
								root: {
										height: 48,
								},
						},
				},
				MuiToolbar: {
						styleOverrides: {
								root: {
										minHeight: 48,
										"@media (min-width: 600px)": {
												minHeight: 48,
										},
								},
						},
				},
		},
});

export default theme;
