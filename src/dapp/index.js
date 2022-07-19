
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

const getStatus = (statusCode) => {
    switch(statusCode) {
        case '10':
            return 'On Time';
        case '20':
            return 'Late Airline';
        case '30':
            return 'Late Weather';
        case '40':
            return 'Late Technical';
        case '50':
            return 'Late Other';
        case '0':
        default:
            return 'Unknown';
    }
}

(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        contract.listenFlightInfo(({ airline, flight, status, timestamp }) => {
            display('Oracles', 'FligtStatusInfo Event', [ { label: 'Fligt Status Info', value: `Status of ${flight} flight of ${airline} airline at ${timestamp} is ${getStatus(status)}`} ]);
        });
    
    });
    window.contract = contract;
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







