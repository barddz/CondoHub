const statusReservaEmAnalise = 'Em análise';
const statusReservaAprovada = 'Aprovada';
const statusReservaRecusada = 'Recusada';
const statusReservaCancelada = 'Cancelada';

bool reservaPodeSerCancelada(String status) {
  return status == statusReservaEmAnalise || status == statusReservaAprovada;
}

bool reservaPodeSerExcluidaPeloAdmin(String status) {
  return status == statusReservaAprovada ||
      status == statusReservaRecusada ||
      status == statusReservaCancelada;
}
