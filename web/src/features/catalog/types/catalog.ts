export type GardenSlug = 'sorting' | 'pathfinding' | 'cellular' | 'graph' | 'fractal' | 'evolution';

export interface GardenSummary {
  slug: GardenSlug;
  name: string;
  description: string;
  algorithms_count: number;
}

export interface AlgorithmSummary {
  slug: string;
  garden: GardenSlug;
  name: string;
  summary: string;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
}

export interface ExerciseSummary {
  id: string;
  algorithm_slug: string;
  title: string;
  instructions: string;
  starter_code: string;
}

export interface AlgorithmDetail extends AlgorithmSummary {
  concept: string;
  explanation: string;
  visualization_guide: string;
  default_params: Record<string, unknown>;
  reference_code: string;
}
