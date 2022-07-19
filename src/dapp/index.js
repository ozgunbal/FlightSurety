
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

const flightInfoEvents = [];

(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        

        contract.listenFlightInfo(({ airline, flight, status, timestamp }) => {
            const hasSameEvent = Boolean(flightInfoEvents.find(info => info.airline === airline && info.flight === flight && info.status === status && info.timestamp === timestamp));
            if (!hasSameEvent) {
                display('Oracles', 'FligtStatusInfo Event', [ { label: 'Fligt Status Info', value: `Status of ${flight} flight of ${airline} airline at ${timestamp} is ${getStatus(status)}`} ]);
                flightInfoEvents.push({
                    airline, flight, timestamp, status
                });
            }
        });

        const selectAirline = DOM.elid('airline-select');
        const selectOracleAirline = DOM.elid('airline-oracle-select');
        contract.airlines.forEach((airline, idx) => {
            const option1 = DOM.makeElement('option', `Airline No: ${idx + 1}: ${airline.slice(0,10)}...`)
            option1.value = airline;
            const option2 = DOM.makeElement('option', `Airline No: ${idx + 1}: ${airline.slice(0,10)}...`)
            option2.value = airline;
            selectAirline.appendChild(option1);
            selectOracleAirline.appendChild(option2);
        })

        const selectFlight = DOM.elid('flight-select');
        const selectOracleFlight = DOM.elid('flight-oracle-select');
        ['Istanbul', 'Amsterdam', 'London', 'Berlin', 'Munich', 'Paris', 'Madrid', 'Barcelona', 'Rome', 'Athens'].forEach(city => {
            const option1 = DOM.makeElement('option', city)
            option1.value = city;
            const option2 = DOM.makeElement('option', city)
            option2.value = city;
            selectFlight.appendChild(option1);
            selectOracleFlight.appendChild(option2);
        })

        const selectTimestamp = DOM.elid('timestamp-select');
        const selectOracleTimestamp = DOM.elid('timestamp-oracle-select'); 
        Array(6).fill(0).map((_, idx) => Math.floor(Date.now() / 1000) + idx * 3600).forEach(timestamp => {
            const option1 = DOM.makeElement('option', `Time: ${new Date(timestamp * 1000).toLocaleString()}`)
            option1.value = timestamp;
            const option2 = DOM.makeElement('option', `Time: ${new Date(timestamp * 1000).toLocaleString()}`)
            option2.value = timestamp;
            selectTimestamp.appendChild(option1);
            selectOracleTimestamp.appendChild(option2);
        })

        const amountInput = DOM.elid('insurance-amount'); 
        amountInput.value = '1';
        DOM.elid('submit-insurance').addEventListener('click', () => {
            const airline = selectAirline.value;
            const flight = selectFlight.value;
            const timestamp = selectTimestamp.value;
            const amount = amountInput.value;
            contract.submitInsurance(airline ,flight, timestamp, amount, (error, { airline, flight, timestamp, amount }) => {
                display('Insurances', 'Submit Insurance', [ { label: 'Insurance', error: error, value: `${amount} ether insurance made for ${flight} flight of ${airline} airline at ${timestamp}`} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            const airline = selectOracleAirline.value;
            const flight = selectOracleFlight.value;
            const timestamp = selectOracleTimestamp.value;
            // Write transaction
            contract.fetchFlightStatus(airline, flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('withdraw-insurance').addEventListener('click', () => {
            contract.withdrawInsurance((error, result) => {
                console.log(result);
                display('Insurances', 'Withdraw Insurance', [ { label: 'Fetch Flight Status', error: error, value: `Withdrawed`} ]);
            });
        })
    
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







