export interface User {
  id: string;
  email: string;
  username: string;
  role: string;
  created_at: string;
}

export interface AuthResponse {
  user: User;
  token: string;
}
