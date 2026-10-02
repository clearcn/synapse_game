% =========================================================================
% SYNAPSE GAME  -  synapse_game_VF.m
% =========================================================================
% AUTHORS & CONTRIBUTION :
%   CHABBERT Melissandre, RACINE Cléa, HEINRICH Sarah
%   Equal contribution of the three authors: game concept, coding, testing.
% DATE (format DD/MM/YY) : 08/09/26
% OCTAVE VERSION : 11.3.0          CODE VERSION : VF 1.0
% SOURCES : No external image, sound or word list. All graphics are drawn
%   with Octave plot/fill/text. AI used: initial concept and first version
%   by the authors; code rewritten and improved with Claude (Anthropic AI),
%   then reviewed and tested by the authors.
%
% CONTEXT : A neuron receives signals from another neuron at a synapse.
%   The presynaptic neuron releases neurotransmitters into the synaptic cleft.
%   - Glutamate (green circle) is EXCITATORY: it raises the membrane
%     potential of the receiving neuron.
%   - GABA (red cross) is INHIBITORY: it lowers the membrane potential.
%   When the potential reaches the threshold, the neuron fires an
%   ACTION POTENTIAL (a "spike") and the potential resets to zero.
%
% GOAL : You are the receptor (blue bar). Catch glutamate, avoid GABA,
%   and make your neuron fire 5 action potentials (spikes) to WIN.
%   You LOSE if you miss 5 glutamate molecules (the neuron runs out of energy).
%
% GAME COMPONENTS / VARIABLES :
%   receptor_x          x position of the receptor (player-cursor)
%   potential           membrane potential of the neuron
%   threshold           firing threshold (random between 4 and 6 each round)
%   spikes              number of action potentials fired (score)
%   energy              remaining energy (lost when a glutamate is missed)
%   neurotransmitters   matrix, one row per molecule = [x y type]
%                       type 1 = glutamate, type 0 = GABA
%
% MAIN LOOP (one frame) : move receptor -> release and move molecules ->
%   capture or miss -> check threshold (spike) -> check win/lose -> draw.
%   Glutamate: +1 potential. GABA: -2 potential. Missed glutamate: -1 energy.
%
% ACROSS TRIALS : each new round resets position, potential, spikes and
%   energy, and draws a NEW random threshold, so rounds are never identical.
%   Speed and release rate increase with each spike (difficulty ramp).
%   The best score is kept between rounds.
%
% WAYS TO MOVE : LEFT / RIGHT arrow keys move the receptor.
%   SPACE = start / replay.   Q = stop the game at any time.
% =========================================================================

function synapse_game_VF()
  global last_key                                             % last key pressed (set by on_key)
  last_key = '';
  fig = figure('Name', 'Synapse Game', 'NumberTitle', 'off', ...
               'Color', [0.08 0.08 0.15], 'KeyPressFcn', @on_key);
  best_score = 0;                                             % best number of spikes over all rounds
  running = true;                                             % false when the player quits

  while running && ishandle(fig)
    % ---- BEGINNING: rules screen ----
    show_screen(fig, 'SYNAPSE GAME', { ...
      'You are the RECEPTOR of a neuron (blue bar).', ...
      'GREEN circle = glutamate : excites the neuron (+1 potential)', ...
      'RED cross = GABA : inhibits the neuron (-2 potential)', ...
      'When the potential reaches the threshold, the neuron FIRES (+1 spike).', ...
      'WIN: 5 spikes.   LOSE: miss 5 glutamate (energy = 0).', ...
      'Move: LEFT / RIGHT arrow keys.   Quit: Q', ...
      '', 'Press SPACE to start'});
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
    else
      message = 'YOU LOSE. Your neuron fell silent.';
    end
    show_screen(fig, message, { ...
      sprintf('Spikes this round: %d     Best: %d', spikes, best_score), ...
      '', 'SPACE = replay        Q = quit'});
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
  global last_key
  goal_spikes = 5;                                            % spikes needed to win
  receptor_x = 5;                                             % start in the middle of the synapse
  potential = 0;                                              % membrane potential
  spikes = 0;                                                 % score of the round
  energy = 5;                                                 % missed glutamate allowed before losing
  threshold = randi([4 6]);                                   % random threshold (replay is not repetitive)
  neurotransmitters = zeros(0, 3);                            % no molecule at the start
  flash = 0;                                                  % frames left to show "ACTION POTENTIAL!"
  result = 0;                                                 % stays 0 if the player quits
  last_key = '';

  % Drawing area (leaves room for the title above)
  clf;
  axes('Position', [0.03 0.03 0.94 0.87], 'Color', [0.1 0.1 0.2], ...
       'XColor', 'none', 'YColor', 'none');

  while ishandle(fig)
    % 1. Move the receptor
    if any(strcmp(last_key, {'leftarrow', 'left'}))
      receptor_x = max(receptor_x - 0.9, 1.2);
    end
    if any(strcmp(last_key, {'rightarrow', 'right'}))
      receptor_x = min(receptor_x + 0.9, 8.8);
    end
    if strcmp(last_key, 'q')
      return;
    end
    last_key = '';

    % 2. Release and move neurotransmitters (harder after each spike)
    fall_speed   = 0.22 + 0.04 * spikes;                      % fall speed per frame
    release_rate = 0.07 + 0.015 * spikes;                     % release probability per frame
    if rand < release_rate
      neurotransmitters(end+1, :) = [10 * rand, 9, rand < 0.65];% 65% glutamate
    end
    neurotransmitters(:, 2) = neurotransmitters(:, 2) - fall_speed;

    % 3. Capture or miss at the receptor level
    arrived = neurotransmitters(:, 2) < 1;                    % reached the receptor membrane
    caught  = arrived & abs(neurotransmitters(:, 1) - receptor_x) < 1.2;
    missed  = arrived & ~caught;
    potential = potential + sum(neurotransmitters(caught, 3) == 1) ...
                          - 2 * sum(neurotransmitters(caught, 3) == 0);
    potential = max(potential, 0);                            % potential cannot go below rest
    energy = energy - sum(neurotransmitters(missed, 3) == 1); % only glutamate counts
    neurotransmitters = neurotransmitters(~arrived, :);       % remove arrived molecules

    % 4. Action potential?
    if potential >= threshold
      spikes = spikes + 1;
      potential = 0;
      flash = 12;
    end

    % 5. Win / lose check
    if spikes >= goal_spikes
      result = 1;
      draw_game(neurotransmitters, receptor_x, potential, threshold, ...
                spikes, goal_spikes, energy, flash);
      pause(0.5);
      return;
    end
    if energy <= 0
      result = -1;
      return;
    end

    % 6. Draw and wait
    draw_game(neurotransmitters, receptor_x, potential, threshold, ...
              spikes, goal_spikes, energy, flash);
    flash = max(flash - 1, 0);
    pause(0.03);
  end
endfunction

% -------------------------------------------------------------------------
% Draw the synapse, molecules, receptor and potential gauge
% -------------------------------------------------------------------------
function draw_game(neurotransmitters, receptor_x, potential, threshold, ...
                   spikes, goal_spikes, energy, flash)
  cla; hold on;
  gauge_y = 1 + 8 * potential / threshold;                    % height of the potential marker
  fill([0 10 10 0], [9.5 9.5 10 10], [0.6 0.6 0.7]);          % presynaptic neuron
  text(0.2, 9.75, 'Presynaptic neuron (releases)', 'Color', 'k');
  fill([0 10 10 0], [0 0 0.3 0.3], [0.3 0.3 0.5]);            % postsynaptic membrane
  if ~isempty(neurotransmitters)
    is_glutamate = neurotransmitters(:, 3) == 1;
    plot(neurotransmitters(is_glutamate, 1), neurotransmitters(is_glutamate, 2), ...
         'o', 'Color', [0.2 1 0.3], 'MarkerSize', 14, 'LineWidth', 3);
    plot(neurotransmitters(~is_glutamate, 1), neurotransmitters(~is_glutamate, 2), ...
         'x', 'Color', [1 0.3 0.3], 'MarkerSize', 14, 'LineWidth', 3);
  end
  plot([receptor_x - 1.2, receptor_x + 1.2], [0.6 0.6], ...
       'Color', [0.3 0.6 1], 'LineWidth', 10);                % receptor
  % Potential gauge on the right (shows how close the neuron is to firing)
  plot([10.8 10.8], [1 9], 'w', 'LineWidth', 2);
  plot(10.8, gauge_y, 's', 'MarkerFaceColor', [1 0.9 0.2], ...
       'MarkerEdgeColor', 'w', 'MarkerSize', 14);
  text(10.3, 9.4, 'FIRE!', 'Color', 'w');
  text(10.3, 0.5, 'rest', 'Color', 'w');
  text(10.2, gauge_y + 0.6, sprintf('%d/%d', potential, threshold), 'Color', 'w');
  if flash > 0
    text(3, 5, 'ACTION POTENTIAL!', 'Color', [1 0.9 0.2], ...
         'FontSize', 20, 'FontWeight', 'bold');
  end
  axis([0 12 0 10]);
  title(sprintf('Spikes: %d / %d      Energy: %d      (LEFT/RIGHT arrows, Q = quit)', ...
                spikes, goal_spikes, energy), 'Color', 'w');
  drawnow;
endfunction

% -------------------------------------------------------------------------
% Display a heading and lines of text (start and end screens)
% -------------------------------------------------------------------------
function show_screen(fig, heading, lines)
  figure(fig);
  clf;
  axes('Position', [0 0 1 1], 'Color', [0.08 0.08 0.15], ...
       'XColor', 'none', 'YColor', 'none');
  axis([0 1 0 1]);
  hold on;
  text(0.5, 0.85, heading, 'Color', [1 0.9 0.2], 'FontSize', 20, ...
       'FontWeight', 'bold', 'HorizontalAlignment', 'center');
  for i = 1:numel(lines)
    text(0.5, 0.72 - 0.08 * (i - 1), lines{i}, 'Color', 'w', ...
         'FontSize', 12, 'HorizontalAlignment', 'center');
  end
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
% Keyboard callback: stores the last key pressed
% -------------------------------------------------------------------------
function on_key(~, event)
  global last_key
  last_key = event.Key;
endfunction
