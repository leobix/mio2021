using JuMP
using Gurobi
using DataFrames
using CSV

##### Problem 2 code skeleton

### Solution

# Note: @__DIR__ points to the directory which contains this script file
# Read data
cd(string(@__DIR__, "/Data"))
sessions = convert(Matrix,CSV.File("Pb2_sessions.csv"; header=true) |> DataFrame!);
courses = convert(Matrix,CSV.File("Pb2_courses.csv"; header=true) |> DataFrame!);
rooms = convert(Matrix,CSV.File("Pb2_rooms.csv"; header=true) |> DataFrame!);
preferences = convert(Matrix,CSV.File("Pb2_preferences.csv"; header=true) |> DataFrame!);
cohorts = convert(Matrix,CSV.File("Pb2_cohorts.csv"; header=true) |> DataFrame!);

cd(@__DIR__)

# Initialize sets and parameters
J = size(sessions,1); #number of sessions
C = size(courses,1); #number of courses
R = size(rooms,1); #number of classrooms
S = size(cohorts,1); #number of student cohorts
D = 2; #number of days
T = 6; #number of time blocks
Q = rooms[:,2]; #classroom capacities
U = courses[:,2]; #course units
N = cohorts[:,2]; #number of students per cohort
ms = cohorts[:,3]; #minimum number of units per cohort
Ms = cohorts[:,4]; #maximum number of units per cohort

mandatory = zeros(S,C); #mandatory courses per cohort
mandatory[1:6,1:5] .= 1;
mandatory[7:13,6:9] .= 1;
mandatory[14:15,10:11] .= 1;
mandatory[16:17,12:13] .= 1;

# Start building model
timelimit = 10*60;
model = Model(Gurobi.Optimizer)
set_optimizer_attribute(model, "TimeLimit", timelimit)

# VARIABLES
@variable(model,z[1:S,1:J,1:D,1:T],Bin);
@variable(model,x[1:J,1:D,1:T,1:R],Bin);

# CONSTRAINTS
@constraint(
    model, [s in 1:S, j in 1:J, d in 1:D, t in 1:T],
    z[s,j,d,t] <= sum(x[j,d,t,r] for r in 1:R)
)

@constraint(
    model,[s in 1:S, d in 1:D, t in 1:T],
    sum(z[s,j,d,t] for j in 1:J) <= 1
)

for c in 1:C
    @constraint(model,
        [s in 1:S],
        sum(z[s,j,d,t]
            for d in 1:D,
                t in 1:T,
                j in sessions[findall(x -> x==c,sessions[:,2]),1])
            <= 1);
end

for s in 1:S
    mandatory_s = findall(x -> x==1,mandatory[s,:]);
    for c in mandatory_s
        @constraint(model,
            sum(z[s,j,d,t]
            for d in 1:D,
                t in 1:T,
                j in sessions[findall(x -> x==c,sessions[:,2]),1])
            >= 1);
    end
end

@constraint(model,[r in 1:R, d in 1:D, t in 1:T],sum(x[j,d,t,r] for j in 1:J) <= 1);

@constraint(model,[j in 1:J],sum(x[j,d,t,r] for r in 1:R, d in 1:D, t in 1:T) == 1);

@constraint(model,[j in 1:J, d in 1:D, t in 1:T],
            sum(N[s]*z[s,j,d,t] for s in 1:S) <= sum(Q[r]*x[j,d,t,r] for r in 1:R))
