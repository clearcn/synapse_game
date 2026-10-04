% =========================================================================
% SYNAPSE GAME  -  synapse_game_VF.m
% =========================================================================
% AUTHORS & CONTRIBUTION :
%   CHABBERT Melissandre, RACINE Cléa, HEINRICH Sarah
%   Equal contribution of the three authors: game concept, coding, testing.
% DATE (format DD/MM/YY) : 08/09/26
% OCTAVE VERSION : 11.3.0          CODE VERSION : VF 1.1
% SOURCES : No external image, sound or word list. All graphics are drawn
%   with Octave line/patch/fill/text. AI used: initial concept and first
%   version by the authors; code rewritten and improved with Claude
%   (Anthropic AI) (visual redesign, speed optimisation, smooth movement),
%   then reviewed and tested by the authors.
%
% CONTEXT : A neuron receives signals from another neuron at a synapse.
%   The presynaptic neuron releases neurotransmitters into the synaptic cleft.
%   - Glutamate (green orb) is EXCITATORY: it raises the membrane
%     potential of the receiving neuron.
%   - GABA (pink cross in a bubble) is INHIBITORY: it lowers the potential.
%   When the potential reaches the threshold, the neuron fires an
%   ACTION POTENTIAL (a "spike") and the potential resets to zero.
%
% GOAL : You are the receptor (blue cup). Catch glutamate, avoid GABA,
%   and make your neuron fire 5 action potentials (spikes) to WIN.
%   You LOSE if you miss 30 glutamate molecules (the neuron runs out of energy).
%
% GAME COMPONENTS / VARIABLES :
%   receptor_x          x position of the receptor (player-cursor)
%   receptor_v          horizontal speed of the receptor (smooth movement)
%   potential           membrane potential of the neuron
%   threshold           firing threshold (random between 4 and 6 each round)
%   spikes              number of action potentials fired (score)
%   energy              remaining energy (lost when a glutamate is missed)
%   neurotransmitters   matrix, one row per molecule = [x y type]
%                       type 1 = glutamate, type 0 = GABA
%
% MAIN LOOP (one frame) : move receptor -> release and move molecules ->
%   capture or miss -> check threshold (spike) -> check win/lose -> update
%   the drawing. Glutamate: +1 potential. GABA: -2 potential.
%   Missed glutamate: -1 energy.
%
% SPEED : the scene is drawn ONCE per round. Each frame we only move the
%   existing graphic objects (set XData / YData) instead of redrawing
%   everything, and the game speed depends on the real time elapsed
%   between two frames, so it runs at the same speed on a slow laptop.
%
% ACROSS TRIALS : each new round resets position, potential, spikes and
%   energy, and draws a NEW random threshold, so rounds are never identical.
%   Speed and release rate increase with each spike (gentle difficulty ramp).
%   The best score is kept between rounds.
%
% WAYS TO MOVE : hold LEFT / RIGHT arrow keys, the receptor accelerates and
%   slides smoothly.   SPACE = start / replay.   Q = stop the game.
% =========================================================================

function synapse_game_VF()
  global last_key key_left key_right
  last_key = '';  key_left = false;  key_right = false;
  fig = figure('Name', 'Synapse Game', 'NumberTitle', 'off', ...
               'Position', [100 100 900 620], 'Color', [0.07 0.08 0.17], ...
               'KeyPressFcn', @on_key, 'KeyReleaseFcn', @on_key_release);
  best_score = 0;                                             % best number of spikes over all rounds
  running = true;                                             % false when the player quits

  white = [0.93 0.94 1];    green = [0.6 0.95 0.72];    pink = [1 0.7 0.74];
  gold  = [1 0.86 0.5];     blue  = [0.7 0.85 1];

  while running && ishandle(fig)
    % ---- BEGINNING: rules screen ----
    show_screen(fig, 'SYNAPSE GAME', { ...
      'You are the RECEPTOR of a neuron (blue cup).', ...
      'GREEN orb = glutamate : excites the neuron (+1 potential)', ...
      'PINK cross = GABA : inhibits the neuron (-2 potential)', ...
      'When the potential reaches the threshold, the neuron FIRES (+1 spike).', ...
      'WIN: 5 spikes.   LOSE: miss 20 glutamate (energy = 0).', ...
      'Move: hold LEFT / RIGHT arrow keys.   Quit: Q', ...
      '', 'Press SPACE to start'}, ...
      {blue, green, pink, white, gold, blue, white, gold}, gold);
    if ~wait_for_key(fig, {'space', 'q'}) || strcmp(last_key, 'q')
      break;
    end

    % ---- GAME ----
    [result, spikes] = play_round(fig);
    if result == 0
      break;                                                  % window closed or Q pressed
    end
    best_score = max(best_score, spikes);

    % ---- END: result screen ----
    if result == 1
      message = 'YOU WIN! Your neuron is firing perfectly.';
      head_color = green;
    else
      message = 'YOU LOSE. Your neuron fell silent.';
      head_color = pink;
    end
    show_screen(fig, message, { ...
      sprintf('Spikes this round: %d     Best: %d', spikes, best_score), ...
      '', 'SPACE = replay        Q = quit'}, {white, white, gold}, head_color);
    if ~wait_for_key(fig, {'space', 'q'}) || strcmp(last_key, 'q')
      running = false;
    end
  end

  if ishandle(fig)
    close(fig);
  end
endfunction

% -------------------------------------------------------------------------
% Play one round. Returns result (1 = win, -1 = lose, 0 = quit) and spikes.
% -------------------------------------------------------------------------
function [result, spikes] = play_round(fig)
  global last_key key_left key_right
  goal_spikes = 5;                                            % spikes needed to win
  n_energy = 20;                                              % missed glutamate allowed before losing
  receptor_x = 5;                                             % start in the middle of the synapse
  receptor_v = 0;                                             % receptor speed
  potential = 0;                                              % membrane potential
  spikes = 0;                                                 % score of the round
  energy = n_energy;
  threshold = randi([4 6]);                                   % random threshold (replay is not repetitive)
  neurotransmitters = zeros(0, 3);                            % no molecule at the start
  flash_t = 0;                                                % seconds left to show "ACTION POTENTIAL!"
  hit_t = 0;  hit_state = 0;                                  % receptor colour feedback (0 none, 1 good, 2 bad)
  result = 0;                                                 % stays 0 if the player quits
  last_key = '';  key_left = false;  key_right = false;

  min_gap = 1.3;                                              % minimum distance between 2 molecules at release
  ref_frame = 0.04;                                           % duration (s) the original per-frame values were made for
  v_max = 0.75;                                               % max receptor speed (units per reference frame)
  part_x = mod((1:24) * 3.71, 10);                            % slow floating particles (decor)
  part_y = mod((1:24) * 2.93, 8.5) + 0.6;
  gold_text = [1 0.86 0.5];
  h = build_scene(threshold, goal_spikes, n_energy);          % draw the whole scene ONCE
  prev_pot = -1;  prev_energy = -1;  prev_spikes = -1;
  prev_flash = false;  flash_shown = false;

  t_prev = tic;
  while ishandle(fig)
    dt = toc(t_prev);  t_prev = tic;
    s  = min(dt / ref_frame, 3);                              % time scale: 1 = nominal frame

    % 1. Move the receptor smoothly (speed follows the keys with inertia)
    target = (double(key_right) - double(key_left)) * v_max;
    receptor_v = receptor_v + (target - receptor_v) * min(1, 0.22 * s);
    receptor_x = receptor_x + receptor_v * s;
    if receptor_x < 1.2
      receptor_x = 1.2;  receptor_v = 0;
    elseif receptor_x > 8.8
      receptor_x = 8.8;  receptor_v = 0;
    end
    if strcmp(last_key, 'q')
      return;
    end
    last_key = '';

    % 2. Release and move neurotransmitters (harder after each spike)
    fall_speed   = (0.22 + 0.02 * spikes) * s;                % fall speed per frame (gentle ramp)
    release_rate = min((0.07 + 0.015 * spikes) * s, 1);       % release probability per frame
    if rand < release_rate
      % pick a free spot: never closer than min_gap to another molecule.
      % All molecules fall at the same speed, so once released they can
      % never get closer to each other: no overlap during the fall.
      for attempt = 1:8
        new_x = 0.5 + 9 * rand;
        if isempty(neurotransmitters) || ...
           all(hypot(neurotransmitters(:, 1) - new_x, neurotransmitters(:, 2) - 9) > min_gap)
          neurotransmitters(end+1, :) = [new_x, 9, rand < 0.65];% 65% glutamate
          break;
        end
      end
    end
    neurotransmitters(:, 2) = neurotransmitters(:, 2) - fall_speed;

    % 3. Capture or miss at the receptor level
    arrived = neurotransmitters(:, 2) < 1;                    % reached the receptor membrane
    caught  = arrived & abs(neurotransmitters(:, 1) - receptor_x) < 1.2;
    missed  = arrived & ~caught;
    n_good  = sum(neurotransmitters(caught, 3) == 1);
    n_bad   = sum(neurotransmitters(caught, 3) == 0);
    potential = potential + n_good - 2 * n_bad;
    potential = max(potential, 0);                            % potential cannot go below rest
    energy = energy - sum(neurotransmitters(missed, 3) == 1); % only glutamate counts
    neurotransmitters = neurotransmitters(~arrived, :);       % remove arrived molecules
    if n_bad > 0
      hit_t = 0.25;  hit_state = 2;
    elseif n_good > 0
      hit_t = 0.15;  hit_state = 1;
    end

    % 4. Action potential?
    if potential >= threshold
      spikes = spikes + 1;
      potential = 0;
      flash_t = 0.5;
    end

    % 5. Win / lose check
    if spikes >= goal_spikes
      result = 1;
    elseif energy <= 0
      result = -1;
    end

    % 6. Update the existing graphic objects (no redraw)
    if ~ishandle(fig)
      return;
    end
    % molecules
    if isempty(neurotransmitters)
      gx = [];  gy = [];  bx = [];  by = [];
    else
      is_glu = neurotransmitters(:, 3) == 1;
      gx = neurotransmitters(is_glu, 1);   gy = neurotransmitters(is_glu, 2);
      bx = neurotransmitters(~is_glu, 1);  by = neurotransmitters(~is_glu, 2);
    end
    upd(h.g_halo, gx, gy);          upd(h.g_mid, gx, gy);
    upd(h.g_core, gx, gy);          upd(h.g_shine, gx - 0.08, gy + 0.08);
    upd(h.g_sat1, gx + 0.34, gy + 0.26);
    upd(h.g_sat2, gx - 0.32, gy + 0.20);
    upd(h.b_halo, bx, by);          upd(h.b_ring, bx, by);        upd(h.b_cross, bx, by);

    % receptor
    cup_x = [receptor_x - 1.2, receptor_x - 1.2, receptor_x + 1.2, receptor_x + 1.2];
    set(h.rec_out, 'XData', cup_x);
    set(h.rec_body, 'XData', cup_x);
    set(h.rec_light, 'XData', cup_x);
    hit_t = hit_t - dt;
    if hit_t <= 0 && hit_state ~= 0
      hit_state = 0;
      set(h.rec_body, 'Color', [0.50 0.78 1]);
    elseif hit_state == 1
      set(h.rec_body, 'Color', [0.60 1 0.78]);
    elseif hit_state == 2
      set(h.rec_body, 'Color', [1 0.62 0.68]);
    end

    % floating particles
    part_y = part_y + 0.012 * s;
    part_y(part_y > 9.0) = 0.7;
    set(h.parts, 'YData', part_y);

    % gauge and counters (only when their value changed)
    if potential ~= prev_pot
      frac = potential / threshold;
      level_y = 1 + 8 * frac;
      set(h.level, 'YData', [1; 1; level_y; level_y], ...
          'FaceColor', [0.5 0.78 1] * (1 - frac) + [1 0.86 0.5] * frac);
      set(h.pot_text, 'String', sprintf('%d/%d', potential, threshold));
      prev_pot = potential;
    end
    if energy ~= prev_energy
      e_frac = max(energy, 0) / n_energy;
      bar_end = 10.95 + 0.9 * e_frac;                         % right end of the energy bar
      set(h.energy_bar, 'XData', [10.95; bar_end; bar_end; 10.95], ...
          'FaceColor', [1 0.62 0.68] * (1 - e_frac) + [0.6 0.95 0.72] * e_frac);
      set(h.energy_text, 'String', sprintf('%d/%d', max(energy, 0), n_energy));
      prev_energy = energy;
    end
    if spikes ~= prev_spikes
      if spikes > 0
        set(h.spike_on, 'XData', 11.4 * ones(1, spikes), 'YData', h.ys_spikes(1:spikes));
      else
        set(h.spike_on, 'XData', NaN, 'YData', NaN);
      end
      prev_spikes = spikes;
    end

    % spike flash: background lights up + message
    flash_t = flash_t - dt;
    if flash_t > 0
      amount = 0.16 * flash_t / 0.5;
      set(h.bg, 'FaceVertexCData', min(h.bg_colors + amount * [1 0.9 0.5; 1 0.9 0.5; 1 0.9 0.5; 1 0.9 0.5], 1));
      prev_flash = true;
      if ~flash_shown
        set([h.flash_txt h.flash_shadow], 'Visible', 'on');
        flash_shown = true;
      end
    elseif prev_flash
      set(h.bg, 'FaceVertexCData', h.bg_colors);
      set([h.flash_txt h.flash_shadow], 'Visible', 'off');
      prev_flash = false;  flash_shown = false;
    end

    drawnow;
    if result ~= 0
      if result == 1
        pause(0.5);
      end
      return;
    end
    pause(max(0.001, 0.016 - toc(t_prev)));                   % cap at about 60 frames per second
  end
endfunction

% -------------------------------------------------------------------------
% Build the whole scene once; returns the handles of the objects that move
% -------------------------------------------------------------------------
function h = build_scene(threshold, goal_spikes, n_energy)
  clf;
  axes('Position', [0.02 0.02 0.96 0.9], 'Color', [0.07 0.08 0.17], ...
       'XColor', 'none', 'YColor', 'none');
  axis([0 12 0 10]);
  hold on;
  gold = [1 0.86 0.5];

  % --- Background: smooth vertical gradient ---
  h.bg_colors = [0.09 0.11 0.23; 0.09 0.11 0.23; 0.19 0.23 0.42; 0.19 0.23 0.42];
  h.bg = patch('Faces', [1 2 3 4], 'Vertices', [0 0; 10 0; 10 9.4; 0 9.4], ...
               'FaceVertexCData', h.bg_colors, 'FaceColor', 'interp', 'EdgeColor', 'none');
  part_x = mod((1:24) * 3.71, 10);
  part_y = mod((1:24) * 2.93, 8.5) + 0.6;
  h.parts = line(part_x, part_y, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 5, ...
                 'MarkerFaceColor', [0.28 0.33 0.55], 'MarkerEdgeColor', 'none');

  % --- Presynaptic neuron (top) : scalloped edge + vesicles ---
  x = linspace(0, 10, 201);
  fill([x 10 0], [9.35 - 0.16 * abs(sin(x * pi / 1.25)) 10 10], [0.64 0.64 0.88], ...
       'EdgeColor', 'none');
  line(0.9:1.25:9.4, 9.58 * ones(1, numel(0.9:1.25:9.4)), 'LineStyle', 'none', ...
       'Marker', 'o', 'MarkerSize', 8, 'MarkerFaceColor', [0.88 0.88 1], 'MarkerEdgeColor', 'none');
  text(5, 9.85, 'Presynaptic neuron (releases)', 'Color', [0.2 0.2 0.4], ...
       'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

  % --- Postsynaptic membrane (bottom) ---
  fill([x 10 0], [0.38 + 0.12 * abs(sin(x * pi / 1.25)) 0 0], [0.36 0.36 0.62], ...
       'EdgeColor', 'none');

  % --- Neurotransmitters: glutamate = orb with 2 small atoms ---
  h.g_halo  = mk_marker('o', 30, [0.20 0.34 0.43], 'none', 1);
  h.g_mid   = mk_marker('o', 21, [0.33 0.60 0.55], 'none', 1);
  h.g_core  = mk_marker('o', 14, [0.66 0.96 0.75], 'none', 1);
  h.g_shine = mk_marker('o', 4,  [1 1 1], 'none', 1);
  h.g_sat1  = mk_marker('o', 7,  [0.55 0.88 0.70], 'none', 1);
  h.g_sat2  = mk_marker('o', 5,  [0.55 0.88 0.70], 'none', 1);
  % GABA = pink cross inside a bubble
  h.b_halo  = mk_marker('o', 30, [0.36 0.22 0.40], 'none', 1);
  h.b_ring  = mk_marker('o', 21, [0.47 0.29 0.48], [0.95 0.58 0.66], 2);
  h.b_cross = line(NaN, NaN, 'LineStyle', 'none', 'Marker', 'x', 'MarkerSize', 10, ...
                   'Color', [1 0.80 0.82], 'LineWidth', 3);

  % --- Receptor: cup (outline, body, highlight) ---
  cup_y = [1.05 0.65 0.65 1.05];
  cup_x = [3.8 3.8 6.2 6.2];
  h.rec_out   = line(cup_x, cup_y, 'Color', [0.25 0.40 0.70], 'LineWidth', 14);
  h.rec_body  = line(cup_x, cup_y, 'Color', [0.50 0.78 1], 'LineWidth', 8);
  h.rec_light = line(cup_x, cup_y + 0.03, 'Color', [0.88 0.96 1], 'LineWidth', 2);

  % --- Side panel ---
  fill([10 12 12 10], [0 0 10 10], [0.06 0.07 0.15], 'EdgeColor', 'none');
  line([10 10], [0 10], 'Color', [0.45 0.58 0.95], 'LineWidth', 2);

  % Potential gauge
  fill([10.2 10.8 10.8 10.2], [1 1 9 9], [0.13 0.15 0.27], 'EdgeColor', 'none');
  h.level = fill([10.2 10.8 10.8 10.2], [1 1 1.001 1.001], [0.5 0.78 1], ...
                 'EdgeColor', 'none');
  for k = 1:(threshold - 1)                                   % one tick per potential unit
    ty = 1 + 8 * k / threshold;
    line([10.2 10.8], [ty ty], 'Color', [0.55 0.6 0.8], 'LineWidth', 1);
  end
  line([10.2 10.8 10.8 10.2 10.2], [1 1 9 9 1], 'Color', [0.9 0.92 1], 'LineWidth', 2);
  text(10.5, 9.4, 'FIRE!', 'Color', gold, 'FontSize', 10, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');
  text(10.5, 0.7, 'rest', 'Color', [0.85 0.87 1], 'FontSize', 9, 'HorizontalAlignment', 'center');
  h.pot_text = text(10.5, 0.25, sprintf('0/%d', threshold), 'Color', gold, ...
                    'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

  % Energy bar (works for any n_energy) and spikes dots
  h.ys_spikes = 6.6 - 0.55 * (0:goal_spikes - 1);
  text(11.4, 9.35, 'ENERGY', 'Color', [0.85 0.87 1], 'FontSize', 8, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');
  fill([10.95 11.85 11.85 10.95], [8.7 8.7 9.0 9.0], [0.13 0.15 0.27], 'EdgeColor', 'none');
  h.energy_bar = fill([10.95 11.85 11.85 10.95], [8.7 8.7 9.0 9.0], [0.6 0.95 0.72], ...
                      'EdgeColor', 'none');
  line([10.95 11.85 11.85 10.95 10.95], [8.7 8.7 9.0 9.0 8.7], 'Color', [0.9 0.92 1], 'LineWidth', 1);
  h.energy_text = text(11.4, 8.35, sprintf('%d/%d', n_energy, n_energy), 'Color', [0.85 0.87 1], ...
                       'FontSize', 8, 'HorizontalAlignment', 'center');
  text(11.4, 7.4, 'SPIKES', 'Color', [0.85 0.87 1], 'FontSize', 8, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');
  line(11.4 * ones(1, goal_spikes), h.ys_spikes, 'LineStyle', 'none', 'Marker', 'o', ...
       'MarkerSize', 10, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.4 0.45 0.65]);
  h.spike_on = line(NaN, NaN, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 10, ...
       'MarkerFaceColor', gold, 'MarkerEdgeColor', [1 0.96 0.85]);

  % "ACTION POTENTIAL!" message (hidden until a spike)
  h.flash_shadow = text(2.92, 4.92, 'ACTION POTENTIAL!', 'Color', [0.05 0.05 0.12], ...
                        'FontSize', 22, 'FontWeight', 'bold', 'Visible', 'off');
  h.flash_txt    = text(3, 5, 'ACTION POTENTIAL!', 'Color', gold, ...
                        'FontSize', 22, 'FontWeight', 'bold', 'Visible', 'off');

  title('LEFT / RIGHT arrows : move        Q : quit', 'Color', [0.75 0.8 1], ...
        'FontSize', 10, 'FontWeight', 'normal');
endfunction

% -------------------------------------------------------------------------
% Create an empty marker line (positions are filled later with upd)
% -------------------------------------------------------------------------
function hd = mk_marker(marker, size, face_color, edge_color, line_width)
  hd = line(NaN, NaN, 'LineStyle', 'none', 'Marker', marker, 'MarkerSize', size, ...
            'MarkerFaceColor', face_color, 'MarkerEdgeColor', edge_color, ...
            'LineWidth', line_width);
endfunction

% -------------------------------------------------------------------------
% Move a marker line to new positions (NaN = nothing to show)
% -------------------------------------------------------------------------
function upd(hd, x, y)
  if isempty(x)
    x = NaN;  y = NaN;
  end
  set(hd, 'XData', x, 'YData', y);
endfunction

% -------------------------------------------------------------------------
% Display a heading and lines of text (start and end screens)
% colors    : cell array, one RGB color per line
% head_color: RGB color of the heading
% -------------------------------------------------------------------------
function show_screen(fig, heading, lines, colors, head_color)
  figure(fig);
  clf;
  axes('Position', [0 0 1 1], 'Color', [0.07 0.08 0.17], ...
       'XColor', 'none', 'YColor', 'none');
  axis([0 1 0 1]);
  hold on;

  % Frame
  rectangle('Position', [0.04 0.04 0.92 0.92], 'Curvature', 0.04, ...
            'FaceColor', [0.11 0.13 0.26], 'EdgeColor', [0.5 0.65 1], 'LineWidth', 2);

  % Heading with a shadow
  text(0.502, 0.848, heading, 'Color', [0.04 0.05 0.12], 'FontSize', 24, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');
  text(0.5, 0.85, heading, 'Color', head_color, 'FontSize', 24, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');

  % Text lines
  for i = 1:numel(lines)
    text(0.5, 0.74 - 0.075 * (i - 1), lines{i}, 'Color', colors{i}, ...
         'FontSize', 12, 'HorizontalAlignment', 'center');
  end

  % Decoration at the bottom: molecules falling onto a receptor
  glu_x = [0.18 0.40 0.62 0.84];   glu_y = [0.15 0.11 0.14 0.10];
  gab_x = [0.29 0.51 0.73];        gab_y = [0.11 0.15 0.11];
  plot(glu_x, glu_y, 'o', 'MarkerSize', 26, 'MarkerFaceColor', [0.20 0.34 0.43], 'MarkerEdgeColor', 'none');
  plot(glu_x, glu_y, 'o', 'MarkerSize', 18, 'MarkerFaceColor', [0.33 0.60 0.55], 'MarkerEdgeColor', 'none');
  plot(glu_x, glu_y, 'o', 'MarkerSize', 12, 'MarkerFaceColor', [0.66 0.96 0.75], 'MarkerEdgeColor', 'none');
  plot(gab_x, gab_y, 'o', 'MarkerSize', 26, 'MarkerFaceColor', [0.36 0.22 0.40], 'MarkerEdgeColor', 'none');
  plot(gab_x, gab_y, 'o', 'MarkerSize', 18, 'MarkerFaceColor', [0.47 0.29 0.48], ...
       'MarkerEdgeColor', [0.95 0.58 0.66], 'LineWidth', 2);
  plot(gab_x, gab_y, 'x', 'Color', [1 0.80 0.82], 'MarkerSize', 9, 'LineWidth', 3);
  cup_x = [0.4 0.4 0.6 0.6];   cup_y = [0.095 0.065 0.065 0.095];
  plot(cup_x, cup_y, 'Color', [0.25 0.40 0.70], 'LineWidth', 12);
  plot(cup_x, cup_y, 'Color', [0.50 0.78 1], 'LineWidth', 7);
  drawnow;
endfunction

% -------------------------------------------------------------------------
% Wait for one of the allowed keys. Returns false if the window was closed.
% -------------------------------------------------------------------------
function window_open = wait_for_key(fig, allowed_keys)
  global last_key
  last_key = '';
  while ishandle(fig) && ~any(strcmp(last_key, allowed_keys))
    pause(0.05);
  end
  window_open = ishandle(fig);
endfunction

% -------------------------------------------------------------------------
% Keyboard callbacks: remember the last key and which arrows are held down
% -------------------------------------------------------------------------
function on_key(~, event)
  global last_key key_left key_right
  last_key = event.Key;
  if any(strcmp(event.Key, {'leftarrow', 'left'}))
    key_left = true;   key_right = false;
  elseif any(strcmp(event.Key, {'rightarrow', 'right'}))
    key_right = true;  key_left = false;
  end
endfunction

function on_key_release(~, event)
  global key_left key_right
  if any(strcmp(event.Key, {'leftarrow', 'left'}))
    key_left = false;
  elseif any(strcmp(event.Key, {'rightarrow', 'right'}))
    key_right = false;
  end
endfunction
