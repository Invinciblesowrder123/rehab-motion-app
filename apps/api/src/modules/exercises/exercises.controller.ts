import { Controller, Get, Param, Query } from '@nestjs/common';
import { ExercisesService } from './exercises.service';

@Controller('exercises')
export class ExercisesController {
  constructor(private readonly exercises: ExercisesService) {}

  @Get()
  list(@Query('bodyPart') bodyPart?: string, @Query('q') q?: string, @Query('limit') limit?: string) {
    return this.exercises.list({ bodyPart, q, limit: Math.min(Number(limit || 20), 50) });
  }

  @Get(':id')
  detail(@Param('id') id: string) { return this.exercises.detail(id); }
}
