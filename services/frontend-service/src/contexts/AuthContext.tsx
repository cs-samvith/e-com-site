'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { User, UserLogin, UserRegister } from '@/types';
import { userService } from '@/services/userServicekk';
import { authUtils } from '@/utils/auth';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  isAuthenticated: boolean;
  login: (credentials: UserLogin) => Promise<void>;
  register: (userData: UserRegister) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState<boolean>(true);

  // Load user on mount
  useEffect(() => {
    const loadUser = async () => {
      try {
        if (authUtils.isAuthenticated()) {
          const userData = await userService.getProfile();
          setUser(userData);
        }
      } catch (error) {
        console.error('Failed to load user:', error);
        authUtils.clearAuth();
      } finally {
        setLoading(false);
      }
    };

    loadUser();
  }, []);

  const login = async (credentials: UserLogin) => {
    setLoading(true);
    try {
      await userService.login(credentials);
      const userData = await userService.getProfile();
      setUser(userData);
    } finally {
      setLoading(false);
    }
  };

  const register = async (userData: UserRegister) => {
    setLoading(true);
    try {
      await userService.register(userData);
      // Auto-login after registration
      await login({ email: userData.email, password: userData.password });
    } finally {
      setLoading(false);
    }
  };

  const logout = async () => {
    setLoading(true);
    try {
      await userService.logout();
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const refreshUser = async () => {
    try {
      const userData = await userService.getProfile();
      setUser(userData);
    } catch (error) {
      console.error('Failed to refresh user:', error);
    }
  };

  const value: AuthContextType = {
    user,
    loading,
    isAuthenticated: !!user,
    login,
    register,
    logout,
    refreshUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};