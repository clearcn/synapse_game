function game_v1()
  global stim_flag
  stim_flag = false;

  % --- parameters ---
  dt     = 0.02;    % time step (s)
  tau    = 0.5;     % leak time constant (s)
  V_rest = 0;
  V_th   = 1;       % firing threshold
  kick   = 0.35;    % jump in V for each key press
  refrac = 0.3;     % refractory period (s): no input right after a spike
  T_game = 30;      % game duration (s)

  % --- state ---
  V = V_rest;  score = 0;  t = 0;  last_spike = -Inf;
  n = 200;  Vhist = zeros(1, n);

  % --- graphics ---
  fig = figure('Name', 'Neuron game', 'KeyPressFcn', @on_key);
  h = plot(1:n, Vhist, 'b', 'LineWidth', 2);
  hold on;
  plot([1 n], [V_th V_th], 'r--');
  hold off;
  axis([1 n -0.2 1.6]);
  ylabel('Membrane potential');

  % --- game loop ---
  while ishandle(fig) && t < T_game
    % 1. input
    if stim_flag && (t - last_spike) > refrac
      V = V + kick;
    end
    stim_flag = false;

    % 2. update: leak toward rest
    V = V + dt * (-(V - V_rest) / tau);

    % 3. spike?
    spiked = false;
    if V >= V_th
      score = score + 1;
      V = V_rest;
      last_spike = t;
      spiked = true;
    end

    % 4. draw
    if spiked
      Vhist = [Vhist(2:end), 1.5];    % draw the spike as a tall peak
    else
      Vhist = [Vhist(2:end), V];
    end
    set(h, 'YData', Vhist);
    title(sprintf('Score: %d   Time left: %.1f s   (press SPACE)', ...
                  score, T_game - t));
    drawnow;
    pause(dt);
    t = t + dt;
  end

  if ishandle(fig)
    title(sprintf('Game over! Final score: %d', score));
  end
end

function on_key(~, evt)
  global stim_flag
  if strcmp(evt.Key, 'space')
    stim_flag = true;
  end
end
