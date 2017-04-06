% the function analyses the results from joinit level test.

% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp 2007

function results = analyze_results_joint(joint, results,MOTORDATA,JOINTDATA)

%% Check for transmission ratio
results.fail.gratio = 0;
results.warn.gratio = 0;
for n = 1:size(results.gratio,1)
    if results.gratio(n).test_failed
        results.fail.gratio = results.fail.gratio + 1;
    end
end

%% Check for hall state 
results.fail.hall_state = 0;
results.warn.hall_state = 0;
for n = 1:size(results.hall_state,1)
    if results.hall_state(n).test_failed
        results.fail.hall_state = results.fail.hall_state + 1;
    end
end

%% Check for cpr
results.fail.cprcheck = 0;
results.warn.cprcheck = 0;
cpr_actual = MOTORDATA.CPR(joint);
for n = 1:size(results.cpr_measured,1)
    % if the measured cpr varies more than 5 count, register
    % failure
    if(abs(cpr_actual-results.cpr_measured(n)) > 5)
        results.fail.cprcheck = results.fail.cprcheck + 1;
    end
end

%% Check for brake holding test
if isfield(results, 'brake_data')
    results.fail.brakecheck = 0;
    results.warn.brakecheck = 0;
    for n = 1:size(results.brake_data,1)
        joint_tq_limit= results.brake_data(n).hold_joint_torque_limit;
        % if the measured torque is smaller than torque limit, register
        % failure
        if(abs(results.brake_data(n).joint_torque_pos) < joint_tq_limit)...
           ||  (abs(results.brake_data(n).joint_torque_neg) < joint_tq_limit)   
            results.fail.brakecheck = results.fail.brakecheck + 1;
        end
    end
end


%% Check for friction
results.fail.friction = 0;
results.warn.friction = 0;
friction_limit = JOINTDATA.FRICTION_LIMIT(joint);
for n = 1:size(results.hass.friction,1)
    % if friction value is more than limit, register failure
    if(results.hass.friction(n) > friction_limit)
        results.fail.friction = results.fail.friction + 1;
    end
end

%% Check for drag
results.fail.drag = 0;
results.fail.dragvariance = 0;
results.warn.drag = 0;
results.warn.dragvariance = 0;
drag_limit = JOINTDATA.DRAG_LIMIT(joint);
drag_var_limit= JOINTDATA.DRAG_VARIANCE_LIMIT(joint);
for n = 1:size(results.hass.drag_measured,1)
    if(results.hass.drag_measured(n).meandrag > drag_limit)
        results.fail.drag = results.fail.drag + 1;
    end
    
    if(results.hass.drag_measured(n).dragvar > drag_var_limit)
        results.fail.dragvariance = results.fail.dragvariance + 1;
    end
end

%% Check for transmission
results.fail.transmission = 0;
results.warn.transmission = 0;
transmission_limit = JOINTDATA.TRANSMISSION_LIMIT(joint);
transmission_warning = JOINTDATA.TRANSMISSION_WARNING(joint);
for n = 1:size(results.hass.transmission,1)
    if( abs(results.hass.transmission(n,1)) > transmission_limit)
        results.fail.transmission = results.fail.transmission + 1;
    elseif (abs(results.hass.transmission(n,1)) > transmission_warning)
        results.warn.transmission = results.warn.transmission + 1;
        
    end
end

%% Check for indexcheck
results.fail.indexcheck = 0;
results.warn.indexcheck = 0;
indexcheck_limit = 100;
for n = 1:size(results.hass.indexcheck.pospts,1)
    diffpos=abs(results.hass.indexcheck.pospts(n,2)-results.hass.indexcheck.pospts(1,2));
    if( diffpos > indexcheck_limit)
        results.fail.indexcheck = results.fail.indexcheck + 1;
    end
end
for n = 1:size(results.hass.indexcheck.negpts,1)
    diffpos=abs(results.hass.indexcheck.negpts(n,2)-results.hass.indexcheck.negpts(1,2));
    if( diffpos > indexcheck_limit)
        results.fail.indexcheck = results.fail.indexcheck + 1;
    end
end

end

%------------- END OF FILE ----------------
