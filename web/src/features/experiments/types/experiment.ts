export interface Experiment {
  id: string;
  user_id: string;
  algorithm_slug: string;
  title: string;
  code: string;
  params: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}
