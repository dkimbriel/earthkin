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
import ManageAccountsIcon from "@mui/icons-material/ManageAccounts";
import FolderSharedIcon from "@mui/icons-material/FolderShared";
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
import UsersPage from "./pages/UsersPage";
import ContentPage from "./pages/ContentPage";

const drawerWidth = 220;

const baseNavItems = [
    { path: "/dashboard", label: "Dashboard", icon: <DashboardIcon /> },
    { path: "/calendar", label: "Calendar", icon: <CalendarMonthIcon /> },
    { path: "/enrollment-applications", label: "Enrollments", icon: <AssignmentIcon /> },
    { path: "/families", label: "Families", icon: <GroupsIcon /> },
    { path: "/programs", label: "Programs", icon: <SchoolIcon /> },
    { path: "/teachers", label: "Teachers", icon: <PersonIcon /> },
    { path: "/locations", label: "Locations", icon: <LocationOnIcon /> },
    { path: "/content", label: "Content", icon: <FolderSharedIcon /> },
];

// Admin-only pages.
const adminNavItems = [
    { path: "/users", label: "Users", icon: <ManageAccountsIcon /> },
];

// Super-admin-only pages.
const superAdminNavItems = [
    { path: "/integrations", label: "Integrations", icon: <SettingsIcon /> },
];

export default function Dashboard() {
    const { user, logout } = useAuth();
    const [mobileOpen, setMobileOpen] = useState(false);

    // Single source of truth for the nav bar height, shared by the fixed header
    // and the two layout spacers below it so they always line up.
    const navHeight = { xs: 72, sm: 104 };

    const isParent = user?.role === "parent";
    const isTeacher = user?.role === "teacher";
    const teacherNavItems = baseNavItems.filter((item) =>
        ["/calendar", "/programs", "/families", "/teachers", "/content"].includes(item.path)
    );
    const navItems = isParent
        ? [{ path: "/dashboard", label: "Home", icon: <DashboardIcon /> }]
        : isTeacher
            ? teacherNavItems
            : [
                ...baseNavItems,
                ...(user?.role === "admin" ? adminNavItems : []),
                ...(user?.super_admin ? superAdminNavItems : []),
            ];

    const drawerContent = (
        <>
            <Box sx={{ height: navHeight, flexShrink: 0 }} />
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
                <Box
                    component="header"
                    sx={(theme) => ({
                        position: "fixed",
                        top: 0,
                        left: 0,
                        right: 0,
                        height: navHeight,
                        zIndex: theme.zIndex.drawer + 1,
                        bgcolor: "primary.main",
                        color: "common.white",
                        display: "flex",
                        alignItems: "center",
                        px: { xs: 2, sm: 3 },
                        gap: 1,
                        boxShadow: 3,
                        overflow: "hidden",
                    })}
                >
                    <IconButton
                        aria-label="open navigation"
                        onClick={() => setMobileOpen(!mobileOpen)}
                        sx={{ color: "common.white", display: { md: "none" } }}
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
                        <Box
                            component="img"
                            src="/logo.png"
                            alt="Earthkin Nature School"
                            sx={{
                                height: { xs: 48, sm: 72 },
                                width: "auto",
                                display: "block",
                            }}
                        />
                    </Box>
                    <Typography
                        noWrap
                        sx={{
                            display: { xs: "none", sm: "block" },
                            maxWidth: 240,
                            overflow: "hidden",
                            textOverflow: "ellipsis",
                        }}
                    >
                        {user.email}
                    </Typography>
                    <Button sx={{ color: "common.white" }} onClick={logout}>
                        Logout
                    </Button>
                </Box>

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
                    <Box sx={{ height: navHeight, flexShrink: 0 }} />
                    <Routes>
                        <Route
                            path="/"
                            element={<Navigate to="/dashboard" replace />}
                        />
                        <Route
                            path="/dashboard"
                            element={
                                isParent ? (
                                    <ParentDashboardPage />
                                ) : isTeacher ? (
                                    <Navigate to="/calendar" replace />
                                ) : (
                                    <DashboardPage />
                                )
                            }
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
                        <Route path="/content" element={<ContentPage />} />
                        {user?.role === "admin" && (
                            <Route path="/users" element={<UsersPage />} />
                        )}
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
