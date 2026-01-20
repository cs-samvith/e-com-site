import api from './api';
import { User, UserRegister, UserLogin, AuthToken, PasswordUpdate } from '@/types';
import { authUtils } from '@/utils/auth';

export const userService = {
  register: async (userData: UserRegister): Promise<User> => {
    const response = await api.post('/users/register', userData);  // Removed /api
    return response.data;
  },

  login: async (credentials: UserLogin): Promise<AuthToken> => {
    const response = await api.post('/users/login', credentials);  // Removed /api
    const token = response.data;
    authUtils.setToken(token.access_token);
    return token;
  },

  logout: async (): Promise<void> => {
    try {
      await api.post('/users/logout');  // Removed /api
    } finally {
      authUtils.clearAuth();
    }
  },

  getProfile: async (): Promise<User> => {
    const response = await api.get('/users/profile');  // Removed /api
    const user = response.data;
    authUtils.setUser(user);
    return user;
  },

  updateProfile: async (updates: Partial<User>): Promise<User> => {
    const response = await api.put('/users/profile', updates);  // Removed /api
    const user = response.data;
    authUtils.setUser(user);
    return user;
  },

  changePassword: async (passwordData: PasswordUpdate): Promise<void> => {
    await api.put('/users/password', passwordData);  // Removed /api
  },

  getUsers: async (limit = 100, offset = 0): Promise<User[]> => {
    const response = await api.get(`/users?limit=${limit}&offset=${offset}`);  // Removed /api
    return response.data;
  },

  getUser: async (id: string): Promise<User> => {
    const response = await api.get(`/users/${id}`);  // Removed /api
    return response.data;
  },
};