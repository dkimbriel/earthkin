import {
    Routes,
    Route,
    NavLink,
    Navigate,
} from "react-router-dom";
import { useState } from "react";
import {
    Box,
    Button,
    AppBar,
    Toolbar,
    Typography,
    Drawer,
    List,
    ListItem,
    ListItemButton,
    ListItemIcon,
    ListItemText,
    IconButton,
} from "@mui/material";
import MenuIcon from "@mui/icons-material/Menu";
import GroupsIcon from "@mui/icons-material/Groups";
import SchoolIcon from "@mui/icons-material/School";
import DashboardIcon from "@mui/icons-material/Dashboard";
import LocationOnIcon from "@mui/icons-material/LocationOn";
import PersonIcon from "@mui/icons-material/Person";
import CalendarMonthIcon from "@mui/icons-material/CalendarMonth";
import AssignmentIcon from "@mui/icons-material/Assignment";
import SettingsIcon from "@mui/icons-material/Settings";
import { useAuth } from "../contexts/AuthContext";

import DashboardPage from "./pages/DashboardPage";
import ParentDashboardPage from "./pages/ParentDashboardPage";
import FamiliesPage from "./pages/FamiliesPage";
import FamilyDetailPage from "./pages/FamilyDetailPage";
import ProgramsPage from "./pages/ProgramsPage";
import ProgramDetailPage from "./pages/ProgramDetailPage";
import ProgramEditPage from "./pages/ProgramEditPage";
import ProgramClassEditPage from "./pages/ProgramClassEditPage";
import EnrollmentDetailPage from "./pages/EnrollmentDetailPage";
import ChildDetailPage from "./pages/ChildDetailPage";
import LocationsPage from "./pages/LocationsPage";
import LocationEditPage from "./pages/LocationEditPage";
import ParentEditPage from "./pages/ParentEditPage";
import TeachersPage from "./pages/TeachersPage";
import TeacherDetailPage from "./pages/TeacherDetailPage";
import CalendarPage from "./pages/CalendarPage";
import EnrollmentApplicationsPage from "./pages/EnrollmentApplicationsPage";
import EnrollmentApplicationDetailPage from "./pages/EnrollmentApplicationDetailPage";
import IntegrationsPage from "./pages/IntegrationsPage";

const drawerWidth = 220;

const baseNavItems = [
    { path: "/dashboard", label: "Dashboard", icon: <DashboardIcon /> },
    { path: "/calendar", label: "Calendar", icon: <CalendarMonthIcon /> },
    { path: "/enrollment-applications", label: "Enrollments", icon: <AssignmentIcon /> },
    { path: "/families", label: "Families", icon: <GroupsIcon /> },
    { path: "/programs", label: "Programs", icon: <SchoolIcon /> },
    { path: "/teachers", label: "Teachers", icon: <PersonIcon /> },
    { path: "/locations", label: "Locations", icon: <LocationOnIcon /> },
];

// Settings/Integrations is admin-only.
const adminNavItems = [
    { path: "/integrations", label: "Integrations", icon: <SettingsIcon /> },
];

export default function Dashboard() {
    const { user, logout } = useAuth();
    const [mobileOpen, setMobileOpen] = useState(false);

    // For now, everyone sees the admin dashboard
    // In the future, you can add role checking here
    const isParent = false;
    const navItems = user?.super_admin
        ? [...baseNavItems, ...adminNavItems]
        : baseNavItems;

    const drawerContent = (
        <>
            <Toolbar sx={{ minHeight: { xs: 64, sm: 80 } }} />
            <Box sx={{ overflow: "auto" }}>
                <List>
                    {navItems.map((item) => (
                        <ListItem key={item.path} disablePadding>
                            <ListItemButton
                                component={NavLink}
                                to={item.path}
                                onClick={() => setMobileOpen(false)}
                                sx={{
                                    "&.active": {
                                        backgroundColor: "action.selected",
                                    },
                                }}
                            >
                                <ListItemIcon>{item.icon}</ListItemIcon>
                                <ListItemText primary={item.label} />
                            </ListItemButton>
                        </ListItem>
                    ))}
                </List>
            </Box>
        </>
    );

    return (
        <Box sx={{ display: "flex" }}>
                <AppBar
                    position="fixed"
                    sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}
                >
                    <Toolbar sx={{ minHeight: { xs: 64, sm: 80 } }}>
                        <IconButton
                            color="inherit"
                            edge="start"
                            aria-label="open navigation"
                            onClick={() => setMobileOpen(!mobileOpen)}
                            sx={{ mr: 1, display: { md: "none" } }}
                        >
                            <MenuIcon />
                        </IconButton>
                        <Box
                            sx={{
                                flexGrow: 1,
                                display: "flex",
                                alignItems: "center",
                                minWidth: 0,
                            }}
                        >
                            <img
                                src="/logo.png"
                                alt="Earthkin"
                                style={{ height: 40, maxWidth: "100%" }}
                            />
                        </Box>
                        <Typography
                            noWrap
                            sx={{
                                mr: 2,
                                display: { xs: "none", sm: "block" },
                                maxWidth: 220,
                                overflow: "hidden",
                                textOverflow: "ellipsis",
                            }}
                        >
                            {user.email}
                        </Typography>
                        <Button color="inherit" onClick={logout}>
                            Logout
                        </Button>
                    </Toolbar>
                </AppBar>

                <Box
                    component="nav"
                    sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}
                    aria-label="navigation"
                >
                    <Drawer
                        variant="temporary"
                        open={mobileOpen}
                        onClose={() => setMobileOpen(false)}
                        ModalProps={{ keepMounted: true }}
                        sx={{
                            display: { xs: "block", md: "none" },
                            "& .MuiDrawer-paper": {
                                width: drawerWidth,
                                boxSizing: "border-box",
                            },
                        }}
                    >
                        {drawerContent}
                    </Drawer>
                    <Drawer
                        variant="permanent"
                        open
                        sx={{
                            display: { xs: "none", md: "block" },
                            "& .MuiDrawer-paper": {
                                width: drawerWidth,
                                boxSizing: "border-box",
                            },
                        }}
                    >
                        {drawerContent}
                    </Drawer>
                </Box>

                <Box
                    component="main"
                    sx={{
                        flexGrow: 1,
                        p: { xs: 2, sm: 3 },
                        width: { xs: "100%", md: `calc(100% - ${drawerWidth}px)` },
                        minWidth: 0,
                    }}
                >
                    <Toolbar sx={{ minHeight: { xs: 64, sm: 80 } }} />
                    <Routes>
                        <Route
                            path="/"
                            element={<Navigate to="/dashboard" replace />}
                        />
                        <Route
                            path="/dashboard"
                            element={isParent ? <ParentDashboardPage /> : <DashboardPage />}
                        />
                        <Route path="/families" element={<FamiliesPage />} />
                        <Route
                            path="/families/:id"
                            element={<FamilyDetailPage />}
                        />
                        <Route path="/programs" element={<ProgramsPage />} />
                        <Route path="/calendar" element={<CalendarPage />} />
                        <Route
                            path="/programs/:id"
                            element={<ProgramDetailPage />}
                        />
                        <Route
                            path="/programs/:id/edit"
                            element={<ProgramEditPage />}
                        />
                        <Route
                            path="/classes/:id/edit"
                            element={<ProgramClassEditPage />}
                        />
                        <Route
                            path="/enrollments/:id"
                            element={<EnrollmentDetailPage />}
                        />
                        <Route
                            path="/children/:id"
                            element={<ChildDetailPage />}
                        />
                        <Route path="/locations" element={<LocationsPage />} />
                        <Route
                            path="/locations/:id/edit"
                            element={<LocationEditPage />}
                        />
                        <Route
                            path="/parents/:id/edit"
                            element={<ParentEditPage />}
                        />
                        <Route path="/teachers" element={<TeachersPage />} />
                        <Route
                            path="/teachers/:id"
                            element={<TeacherDetailPage />}
                        />
                        <Route
                            path="/enrollment-applications"
                            element={<EnrollmentApplicationsPage />}
                        />
                        <Route
                            path="/enrollment-applications/:id"
                            element={<EnrollmentApplicationDetailPage />}
                        />
                        {user?.super_admin && (
                            <Route
                                path="/integrations"
                                element={<IntegrationsPage />}
                            />
                        )}
                    </Routes>
                </Box>
            </Box>
    );
}
