import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { roleConfig, getDefaultPath, canAccessPath } from '../config/roleConfig';
import { loginPageContent } from '../config/loginPageContent';

interface User {
  id: string;
  email: string;
  role: 'viewer' | 'builder' | 'admin' | 'owner';
  firstName: string;
  lastName: string;
  avatar?: string;
  userType?: 'ai_engineer' | 'business_analyst' | 'content_creator' | 'automation_migrant' | 'ai_novice';
  onboardingCompleted: boolean;
  preferences: {
    theme: string;
    notifications: boolean;
    twoFactorEnabled: boolean;
  };
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  sessionToken: string | null;
}

interface LoginCredentials {
  email: string;
  password: string;
  rememberMe?: boolean;
}

export const useAuth = () => {
  const [authState, setAuthState] = useState<AuthState>({
    user: null,
    isAuthenticated: false,
    isLoading: true,
    sessionToken: null
  });
  const [initialized, setInitialized] = useState(false);

  const navigate = useNavigate();

  // 🔐 Initialize authentication state from localStorage - SINGLE RUN ONLY
  useEffect(() => {
    if (initialized) return;
    
    const initializeAuth = async () => {
      try {
        const storedAuth = localStorage.getItem('onevault_auth');
        const storedUser = localStorage.getItem('onevault_user');

        if (storedAuth && storedUser) {
          const authData = JSON.parse(storedAuth);
          const userData = JSON.parse(storedUser);

          // Simple validation - just check token exists
          if (authData.sessionToken && authData.sessionToken.length > 10) {
            setAuthState({
              user: userData,
              isAuthenticated: true,
              isLoading: false,
              sessionToken: authData.sessionToken
            });
          } else {
            localStorage.removeItem('onevault_auth');
            localStorage.removeItem('onevault_user');
            setAuthState(prev => ({ ...prev, isLoading: false }));
          }
        } else {
          setAuthState(prev => ({ ...prev, isLoading: false }));
        }
      } catch (error) {
        setAuthState(prev => ({ ...prev, isLoading: false }));
      }
      
      setInitialized(true);
    };

    const timer = setTimeout(initializeAuth, 100); // Small delay to prevent immediate loops
    return () => clearTimeout(timer);
  }, [initialized]);



  // 🎯 Login function
  const login = useCallback(async (credentials: LoginCredentials) => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true }));

      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Mock authentication logic - in real app, this would be an API call
      if (credentials.email && credentials.password.length >= 8) {
        const mockUser: User = {
          id: 'user_' + Date.now(),
          email: credentials.email,
          role: 'builder', // Default role for demo
          firstName: 'Neural',
          lastName: 'Architect',
          userType: 'ai_engineer',
          onboardingCompleted: false,
          preferences: {
            theme: 'neural-dark',
            notifications: true,
            twoFactorEnabled: false
          }
        };

        const mockSessionToken = 'neural_session_' + Date.now() + '_' + Math.random().toString(36);

        // Store auth data
        const authData = {
          sessionToken: mockSessionToken,
          loginTime: new Date().toISOString(),
          rememberMe: credentials.rememberMe || false
        };

        localStorage.setItem('onevault_auth', JSON.stringify(authData));
        localStorage.setItem('onevault_user', JSON.stringify(mockUser));

        setAuthState({
          user: mockUser,
          isAuthenticated: true,
          isLoading: false,
          sessionToken: mockSessionToken
        });

        // Redirect immediately after successful login
        const defaultPath = getDefaultPath(mockUser.role);
        navigate(defaultPath, { replace: true });

        return {
          success: true,
          message: loginPageContent.success.login
        };
      } else {
        throw new Error(loginPageContent.form.validation.login_failed);
      }
    } catch (error) {
      setAuthState(prev => ({ ...prev, isLoading: false }));
      return {
        success: false,
        message: error instanceof Error ? error.message : 'Login failed'
      };
    }
  }, [navigate]);

  // 🚪 Logout function
  const logout = useCallback(async () => {
    try {
      // Clear stored auth data
      localStorage.removeItem('onevault_auth');
      localStorage.removeItem('onevault_user');

      setAuthState({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        sessionToken: null
      });

      // Redirect to login
      navigate('/login');

      return {
        success: true,
        message: loginPageContent.success.logout
      };
    } catch (error) {
      console.error('Logout error:', error);
      return {
        success: false,
        message: 'Logout failed'
      };
    }
  }, [navigate]);

  // 🔄 Refresh user data
  const refreshUser = useCallback(async () => {
    if (!authState.sessionToken) return;

    try {
      // In real app, fetch updated user data from API
      // For now, just check if token exists
      if (!authState.sessionToken || authState.sessionToken.length < 10) {
        await logout();
      }
    } catch (error) {
      await logout();
    }
  }, [authState.sessionToken, logout]);

  // 👤 Update user profile
  const updateUser = useCallback(async (updates: Partial<User>) => {
    if (!authState.user) return { success: false, message: 'No user logged in' };

    try {
      const updatedUser = { ...authState.user, ...updates };
      
      localStorage.setItem('onevault_user', JSON.stringify(updatedUser));
      
      setAuthState(prev => ({
        ...prev,
        user: updatedUser
      }));

      return { success: true, message: 'Profile updated successfully' };
    } catch (error) {
      console.error('User update error:', error);
      return { success: false, message: 'Failed to update profile' };
    }
  }, [authState.user]);

  // 🛡️ Check if user has permission
  const hasPermission = useCallback((permission: string): boolean => {
    if (!authState.user) return false;
    
    const allowedRoles = roleConfig.permissions[permission as keyof typeof roleConfig.permissions];
    return allowedRoles?.includes(authState.user.role) || false;
  }, [authState.user]);

  // 🗺️ Check if user can access path
  const canAccess = useCallback((path: string): boolean => {
    if (!authState.user) return false;
    return canAccessPath(authState.user.role, path);
  }, [authState.user]);

  // 🎨 Get user's role theme
  const getUserTheme = useCallback(() => {
    if (!authState.user) return roleConfig.themes.viewer;
    return roleConfig.themes[authState.user.role];
  }, [authState.user]);

  // 📱 Get user's onboarding flow
  const getOnboardingFlow = useCallback(() => {
    if (!authState.user?.userType) return null;
    return roleConfig.onboarding[authState.user.userType];
  }, [authState.user]);

  // 🔄 Complete onboarding
  const completeOnboarding = useCallback(async () => {
    if (!authState.user) return { success: false };

    const result = await updateUser({ onboardingCompleted: true });
    return result;
  }, [authState.user, updateUser]);

  return {
    // State
    user: authState.user,
    isAuthenticated: authState.isAuthenticated,
    isLoading: authState.isLoading,
    sessionToken: authState.sessionToken,
    
    // Actions
    login,
    logout,
    refreshUser,
    updateUser,
    completeOnboarding,
    
    // Utilities
    hasPermission,
    canAccess,
    getUserTheme,
    getOnboardingFlow,
    
    // Role info
    roleConfig: authState.user ? roleConfig.roles[authState.user.role] : null
  };
}; 