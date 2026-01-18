// Product types
export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  inventory_count: number;
  created_at: string;
  updated_at: string;
}

export interface ProductCreate {
  name: string;
  description: string;
  price: number;
  category: string;
  inventory_count: number;
}

// User types
export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  created_at: string;
  updated_at: string;
}

export interface UserRegister {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  phone?: string;
}

export interface UserLogin {
  email: string;
  password: string;
}

export interface AuthToken {
  access_token: string;
  token_type: string;
  expires_in: number;
}

export interface UserProfile extends User {}

export interface PasswordUpdate {
  old_password: string;
  new_password: string;
}