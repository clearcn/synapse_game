function synapse_game()
  global key
  key = '';
  fig = figure('KeyPressFcn', @on_key);

  px = 5;  pot = 0;  score = 0;   % position du récepteur, potentiel, score
  seuil = 5;
  nt = zeros(0, 3);               % neurotransmetteurs : [x y type]

  for step = 1:600
    if ~ishandle(fig), break; end

    % 1. Déplacement du récepteur
    if ismember(key, {'leftarrow', 'a'}),  px = max(px - 0.8, 1); end
    if ismember(key, {'rightarrow', 'd'}), px = min(px + 0.8, 9); end
    key = '';

    % 2. Libération d'un neurotransmetteur (1 = glutamate, 0 = GABA)
    if rand < 0.08
      nt(end+1, :) = [10*rand, 10, rand < 0.7];
    end
    nt(:, 2) = nt(:, 2) - 0.3;    % ils tombent dans la fente synaptique

    % 3. Capture par le récepteur
    arrive = nt(:, 2) < 0.8;
    pris   = arrive & abs(nt(:, 1) - px) < 1;
    pot = pot + sum(nt(pris, 3) == 1) - sum(nt(pris, 3) == 0);
    pot = max(pot, 0);
    nt = nt(~arrive, :);          % on supprime ceux arrivés en bas

    % 4. Potentiel d'action ?
    if pot >= seuil
      score = score + 1;
      pot = 0;
    end

    % 5. Dessin
    cla; hold on;
    plot(nt(nt(:,3)==1, 1), nt(nt(:,3)==1, 2), 'go', 'MarkerSize', 12, 'LineWidth', 3);
    plot(nt(nt(:,3)==0, 1), nt(nt(:,3)==0, 2), 'rx', 'MarkerSize', 12, 'LineWidth', 3);
    plot([px-1 px+1], [0.4 0.4], 'b', 'LineWidth', 8);
    axis([0 10 0 10]);
    title(sprintf('Score : %d   Potentiel : %d / %d   (flèches ou A/D)', ...
                  score, pot, seuil));
    drawnow;
    pause(0.03);
  end
end

function on_key(~, evt)
  global key
  key = evt.Key;
end
